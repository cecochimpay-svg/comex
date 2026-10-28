-- COMEX · Seguridad de acceso
-- Ejecutar una sola vez en Supabase > SQL Editor. Se puede volver a correr sin romper nada.
--
-- IMPORTANTE: después de correrlo, las versiones viejas de la app ya no pueden ingresar.
-- Instalar la versión nueva en todas las PCs el mismo día.
--
-- Qué hace:
--   * Cifra las contraseñas (bcrypt) y borra el texto plano.
--   * Nadie puede leer la tabla de usuarios con la clave pública de la app.
--   * El ingreso se valida en el servidor con comex_login().
--   * 5 intentos fallidos bloquean el usuario 15 minutos.
--   * Registra cada intento de ingreso en comex_accesos.
--
-- Para crear un usuario o cambiarle la contraseña, desde el Table Editor de Supabase
-- escribí la contraseña en la columna "clave": se cifra sola al guardar y la columna queda vacía.

create extension if not exists pgcrypto with schema extensions;

-- 1. Columnas nuevas
alter table public.comex_usuarios
  add column if not exists clave_hash text,
  add column if not exists intentos_fallidos int not null default 0,
  add column if not exists bloqueado_hasta timestamptz,
  add column if not exists ultimo_ingreso timestamptz;

alter table public.comex_usuarios alter column clave drop not null;

-- 2. Toda contraseña que se escriba en "clave" se cifra y se borra el texto plano
create or replace function public.comex_usuarios_cifrar_clave()
returns trigger
language plpgsql
set search_path = public, extensions
as $$
begin
  if new.clave is not null and trim(new.clave) <> '' then
    new.clave_hash := crypt(trim(new.clave), gen_salt('bf', 10));
    new.intentos_fallidos := 0;
    new.bloqueado_hasta := null;
  end if;
  new.clave := null;
  return new;
end;
$$;

drop trigger if exists trg_comex_usuarios_cifrar_clave on public.comex_usuarios;
create trigger trg_comex_usuarios_cifrar_clave
  before insert or update of clave on public.comex_usuarios
  for each row execute function public.comex_usuarios_cifrar_clave();

-- 3. Cifrar las contraseñas que ya existen (dispara el trigger de arriba)
update public.comex_usuarios set clave = clave where clave is not null;

-- 4. Registro de accesos
create table if not exists public.comex_accesos (
  id bigint generated always as identity primary key,
  fecha timestamptz not null default now(),
  usuario text,
  exito boolean not null,
  motivo text,
  equipo text
);

create index if not exists idx_comex_accesos_fecha on public.comex_accesos (fecha desc);

-- 5. Validación de ingreso en el servidor
create or replace function public.comex_login(p_usuario text, p_clave text, p_equipo text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  u public.comex_usuarios%rowtype;
  max_intentos constant int := 5;
  fallidos int;
begin
  select * into u
  from public.comex_usuarios
  where lower(usuario) = lower(trim(p_usuario))
  limit 1;

  if not found then
    perform pg_sleep(0.4);
    insert into public.comex_accesos (usuario, exito, motivo, equipo)
    values (left(p_usuario, 80), false, 'usuario inexistente', left(p_equipo, 120));
    return jsonb_build_object('ok', false, 'motivo', 'credenciales');
  end if;

  if u.bloqueado_hasta is not null and u.bloqueado_hasta > now() then
    insert into public.comex_accesos (usuario, exito, motivo, equipo)
    values (u.usuario, false, 'bloqueado', left(p_equipo, 120));
    return jsonb_build_object('ok', false, 'motivo', 'bloqueado', 'hasta', u.bloqueado_hasta);
  end if;

  if u.clave_hash is null or crypt(trim(p_clave), u.clave_hash) <> u.clave_hash then
    fallidos := u.intentos_fallidos + 1;
    update public.comex_usuarios
    set intentos_fallidos = fallidos,
        bloqueado_hasta = case when fallidos >= max_intentos then now() + interval '15 minutes' else null end
    where id = u.id;

    insert into public.comex_accesos (usuario, exito, motivo, equipo)
    values (u.usuario, false, 'clave incorrecta', left(p_equipo, 120));

    if fallidos >= max_intentos then
      return jsonb_build_object('ok', false, 'motivo', 'bloqueado', 'hasta', now() + interval '15 minutes');
    end if;
    return jsonb_build_object('ok', false, 'motivo', 'credenciales', 'restantes', max_intentos - fallidos);
  end if;

  if coalesce(u.estado, '') <> 'ACTI' then
    insert into public.comex_accesos (usuario, exito, motivo, equipo)
    values (u.usuario, false, 'usuario inactivo', left(p_equipo, 120));
    return jsonb_build_object('ok', false, 'motivo', 'inactivo');
  end if;

  update public.comex_usuarios
  set intentos_fallidos = 0, bloqueado_hasta = null, ultimo_ingreso = now()
  where id = u.id;

  insert into public.comex_accesos (usuario, exito, motivo, equipo)
  values (u.usuario, true, 'ingreso', left(p_equipo, 120));

  return jsonb_build_object(
    'ok', true,
    'id', u.id,
    'usuario', u.usuario,
    'rol', upper(coalesce(to_jsonb(u) ->> 'rol', 'COMEX'))
  );
end;
$$;

revoke all on function public.comex_login(text, text, text) from public;
grant execute on function public.comex_login(text, text, text) to anon, authenticated;

-- 6. Cerrar la lectura directa: solo comex_login() (y el panel de Supabase) acceden a usuarios y accesos
alter table public.comex_usuarios enable row level security;
alter table public.comex_accesos enable row level security;
revoke all on public.comex_usuarios from anon, authenticated;
revoke all on public.comex_accesos from anon, authenticated;

notify pgrst, 'reload schema';

-- Consultas útiles:
--   select * from public.comex_accesos order by fecha desc limit 100;
--   update public.comex_usuarios set intentos_fallidos = 0, bloqueado_hasta = null where usuario = 'jlopez';
