-- COMEX · Datos protegidos: solo se accede con una sesión iniciada
-- Ejecutar una sola vez en Supabase > SQL Editor, DESPUÉS de 002. Se puede volver a correr sin romper nada.
--
-- IMPORTANTE: después de correrlo, las versiones viejas de COMEX y de COMEX Despachos dejan de ver
-- los vuelos y programas. Publicar la web y actualizar todas las PCs el mismo día.
--
-- Qué hace:
--   * Cada usuario de comex_usuarios pasa a tener su cuenta en Supabase Auth, con la MISMA contraseña
--     (se copia el hash bcrypt: nadie tiene que cambiar la clave).
--   * Crear un usuario, cambiarle la clave o darlo de baja se sigue haciendo igual que antes desde el
--     Table Editor de comex_usuarios (columnas "clave" y "estado"): la cuenta se actualiza sola.
--   * Sin sesión iniciada (clave pública sola) ya no se puede leer ni escribir:
--       logistitcas_temporada, comex_programa_trabajo, comex_proyeccion_dias, clientes_consignatarios
--   * Vuelos: todos los usuarios activos los ven (Despachos los necesita para el packing list),
--     pero cada uno solo crea, edita o borra los suyos. ADM puede todo.
--   * Clientes y consignatarios: todos los leen, solo ADM los modifica.
--
-- Quedan afuera a propósito (los escribe el programa de etiquetado con la clave pública):
--   agronet_marcas, vista_pallet_despachados, vista_pallet_stock_general.

create extension if not exists pgcrypto with schema extensions;

-- 1. Vínculo entre comex_usuarios y su cuenta de Supabase Auth
alter table public.comex_usuarios add column if not exists auth_id uuid unique;

-- Correo interno de cada usuario (no se envían mails; solo identifica la cuenta)
create or replace function public.comex_email(p_usuario text)
returns text
language sql
immutable
as $$
  select regexp_replace(lower(trim(p_usuario)), '[^a-z0-9._-]', '_', 'g') || '@comex.cecoargentina.com'
$$;

-- 2. Mantener la cuenta de Auth igual a comex_usuarios (clave, nombre y estado)
create or replace function public.comex_usuarios_sincronizar_auth()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  v_id uuid := new.auth_id;
  v_email text := public.comex_email(new.usuario);
  v_baja timestamptz := case when coalesce(new.estado, '') = 'ACTI' then null else now() + interval '100 years' end;
  v_adoptada boolean := false;
begin
  if new.clave_hash is null or new.usuario is null then
    return new;
  end if;

  if v_id is not null and not exists (select 1 from auth.users where id = v_id) then
    v_id := null;
  end if;
  if v_id is null then
    select id into v_id from auth.users where email = v_email;
    -- Cuenta que ya existía sin estar vinculada (por ejemplo, creada desde afuera): se cortan sus sesiones
    v_adoptada := v_id is not null;
  end if;

  if v_id is null then
    v_id := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, banned_until,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', v_email,
      new.clave_hash, now(), v_baja,
      jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
      jsonb_build_object('usuario', new.usuario), now(), now(),
      '', '', '', ''
    );
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (
      gen_random_uuid(), v_id, v_id::text,
      jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true),
      'email', now(), now(), now()
    );
  else
    update auth.users
    set email = v_email,
        encrypted_password = new.clave_hash,
        banned_until = v_baja,
        raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('usuario', new.usuario),
        updated_at = now()
    where id = v_id;
    update auth.identities
    set identity_data = identity_data || jsonb_build_object('email', v_email), updated_at = now()
    where user_id = v_id and provider = 'email';
  end if;

  -- Al dar de baja o cambiar la clave se cierran las sesiones abiertas de ese usuario
  if v_adoptada or (tg_op = 'UPDATE' and (v_baja is not null or new.clave_hash is distinct from old.clave_hash)) then
    delete from auth.sessions where user_id = v_id;
  end if;

  new.auth_id := v_id;
  return new;
end;
$$;

-- Corre después de trg_comex_usuarios_cifrar_clave (los triggers se ejecutan en orden alfabético)
drop trigger if exists trg_comex_usuarios_sincronizar_auth on public.comex_usuarios;
create trigger trg_comex_usuarios_sincronizar_auth
  before insert or update of clave, clave_hash, usuario, estado on public.comex_usuarios
  for each row execute function public.comex_usuarios_sincronizar_auth();

-- 3. Crear las cuentas de los usuarios que ya existen (dispara el trigger de arriba)
update public.comex_usuarios set estado = estado;

-- 4. Quién es el usuario de la sesión (solo usuarios activos)
create or replace function public.comex_usuario_actual()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select u.usuario
  from public.comex_usuarios u
  where u.auth_id = auth.uid() and coalesce(u.estado, '') = 'ACTI'
  limit 1
$$;

create or replace function public.comex_es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select upper(coalesce(to_jsonb(u) ->> 'rol', '')) in ('ADM', 'ADMIN') or upper(u.usuario) = 'ADMIN'
    from public.comex_usuarios u
    where u.auth_id = auth.uid() and coalesce(u.estado, '') = 'ACTI'
    limit 1
  ), false)
$$;

revoke all on function public.comex_usuario_actual() from public;
revoke all on function public.comex_es_admin() from public;
grant execute on function public.comex_usuario_actual() to authenticated;
grant execute on function public.comex_es_admin() to authenticated;
revoke all on function public.comex_usuarios_sincronizar_auth() from public, anon, authenticated;

-- 5. Reglas por tabla (se borran las reglas anteriores de estas tablas)
do $$
declare
  t text;
  p record;
begin
  foreach t in array array['logistitcas_temporada', 'comex_programa_trabajo', 'comex_proyeccion_dias', 'clientes_consignatarios'] loop
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('alter table public.%I enable row level security', t);
    -- Sin sesión: error de permisos (la app de Windows lo toma como "sin conexión" y usa sus datos locales)
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;

-- Vuelos: todos los activos leen; cada uno modifica lo suyo; ADM todo
create policy comex_vuelos_leer on public.logistitcas_temporada
  for select to authenticated
  using (public.comex_usuario_actual() is not null);

create policy comex_vuelos_crear on public.logistitcas_temporada
  for insert to authenticated
  with check (public.comex_es_admin() or lower(trim(usuario)) = lower(public.comex_usuario_actual()));

create policy comex_vuelos_editar on public.logistitcas_temporada
  for update to authenticated
  using (public.comex_es_admin() or lower(trim(usuario)) = lower(public.comex_usuario_actual()))
  with check (public.comex_es_admin() or lower(trim(usuario)) = lower(public.comex_usuario_actual()));

create policy comex_vuelos_borrar on public.logistitcas_temporada
  for delete to authenticated
  using (public.comex_es_admin() or lower(trim(usuario)) = lower(public.comex_usuario_actual()));

-- Programa de trabajo y proyección: los usa todo el equipo COMEX
create policy comex_programa_todo on public.comex_programa_trabajo
  for all to authenticated
  using (public.comex_usuario_actual() is not null)
  with check (public.comex_usuario_actual() is not null);

create policy comex_proyeccion_todo on public.comex_proyeccion_dias
  for all to authenticated
  using (public.comex_usuario_actual() is not null)
  with check (public.comex_usuario_actual() is not null);

-- Clientes y consignatarios: todos leen, ADM modifica
create policy comex_clientes_leer on public.clientes_consignatarios
  for select to authenticated
  using (public.comex_usuario_actual() is not null);

create policy comex_clientes_admin on public.clientes_consignatarios
  for all to authenticated
  using (public.comex_es_admin())
  with check (public.comex_es_admin());

notify pgrst, 'reload schema';

-- Además, en el panel de Supabase:
--   Authentication > Sign In / Providers > desactivar "Allow new users to sign up"
--   (así nadie puede crearse una cuenta desde afuera; los usuarios salen solo de comex_usuarios).
--
-- Consultas útiles:
--   select usuario, estado, auth_id from public.comex_usuarios order by usuario;
--   select email, banned_until, last_sign_in_at from auth.users order by email;
