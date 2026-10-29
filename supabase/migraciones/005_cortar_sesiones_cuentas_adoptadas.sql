-- COMEX · Ajuste de 004: si al vincular un usuario ya existía una cuenta con su correo
-- (por ejemplo, creada desde afuera mientras el registro estaba abierto), se cortan sus sesiones.
-- Ejecutar en Supabase > SQL Editor si 004 ya se corrió antes de este ajuste.
-- Es la misma función de 004 (versión actual del archivo); se puede volver a correr.
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

-- Y en el panel: Authentication > Sign In / Providers > desactivar "Allow new users to sign up".
