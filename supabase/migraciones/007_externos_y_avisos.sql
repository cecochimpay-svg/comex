-- COMEX · Usuarios externos aislados y avisos de cambios para el administrador
-- Ejecutar una sola vez en Supabase > SQL Editor, DESPUÉS de 004, 005 y 006. Se puede volver a correr.
--
-- 1. Usuarios EXTERNOS (operadores de carga de otras empresas: Jetcargo, TCI…)
--    En comex_usuarios poné rol = 'EXTERNO'. Esos usuarios:
--      * ven, crean, editan y borran SOLO sus despachos (logistitcas_temporada con usuario = el suyo);
--      * no pueden leer ni escribir programa de trabajo, proyección ni clientes/consignatarios.
--    Los demás usuarios (COMEX internos, COMEX Despachos, ADM) siguen exactamente igual que antes:
--    Despachos necesita leer todos los vuelos para el packing list.
--
-- 2. Avisos al administrador
--    Cada alta, edición o baja de un despacho hecha por un usuario que no es ADM queda en
--    comex_notificaciones (la carga un trigger: vale para la app, la importación de Excel y la
--    sincronización). La app COMEX muestra a los ADM un aviso flotante que queda hasta que lo cierran.
--    Una re-subida sin cambios reales (sincronización) no genera aviso.
--
-- Después de correrlo:
--   update public.comex_usuarios set rol = 'EXTERNO'
--   where usuario in ('mcurcio@jetcargo.com.ar', 'mmendy@trust-cargo.com');

-- ───────────────────────── 1. Usuarios externos ─────────────────────────

alter table public.comex_usuarios add column if not exists rol text;

create or replace function public.comex_es_externo()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select upper(coalesce(u.rol, '')) = 'EXTERNO'
    from public.comex_usuarios u
    where u.auth_id = auth.uid() and coalesce(u.estado, '') = 'ACTI'
    limit 1
  ), false)
$$;

revoke all on function public.comex_es_externo() from public;
grant execute on function public.comex_es_externo() to authenticated;

-- Vuelos: los externos leen sólo los suyos (crear/editar/borrar ya eran sólo los suyos desde 004).
drop policy if exists comex_vuelos_leer on public.logistitcas_temporada;
create policy comex_vuelos_leer on public.logistitcas_temporada
  for select to authenticated
  using (
    (select public.comex_usuario_actual()) is not null
    and (
      not (select public.comex_es_externo())
      or lower(trim(usuario)) = lower((select public.comex_usuario_actual()))
    )
  );

-- Programa, proyección y clientes: sólo usuarios internos.
drop policy if exists comex_programa_todo on public.comex_programa_trabajo;
create policy comex_programa_todo on public.comex_programa_trabajo
  for all to authenticated
  using ((select public.comex_usuario_actual()) is not null and not (select public.comex_es_externo()))
  with check ((select public.comex_usuario_actual()) is not null and not (select public.comex_es_externo()));

drop policy if exists comex_proyeccion_todo on public.comex_proyeccion_dias;
create policy comex_proyeccion_todo on public.comex_proyeccion_dias
  for all to authenticated
  using ((select public.comex_usuario_actual()) is not null and not (select public.comex_es_externo()))
  with check ((select public.comex_usuario_actual()) is not null and not (select public.comex_es_externo()));

drop policy if exists comex_clientes_leer on public.clientes_consignatarios;
create policy comex_clientes_leer on public.clientes_consignatarios
  for select to authenticated
  using ((select public.comex_usuario_actual()) is not null and not (select public.comex_es_externo()));

-- ───────────────────────── 2. Avisos al administrador ─────────────────────────

create table if not exists public.comex_notificaciones (
  id bigint generated always as identity primary key,
  fecha timestamptz not null default now(),
  usuario text,              -- quién hizo el cambio
  accion text not null,      -- ALTA | EDICION | BAJA
  registro text,
  awb text,
  destino text,
  vuelo text,
  semana int,
  cambios jsonb,             -- en EDICION: {"columna": [antes, después]}
  cerrada boolean not null default false,
  cerrada_por text,
  cerrada_en timestamptz
);

create index if not exists idx_comex_notificaciones_abiertas
  on public.comex_notificaciones (fecha) where not cerrada;

create or replace function public.comex_vuelos_avisar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quien text := public.comex_usuario_actual();
  v_fila jsonb;
  v_cambios jsonb;
  v_accion text;
  v_semana text;
begin
  -- Sólo cambios hechos con la sesión de un usuario COMEX que no es administrador.
  if v_quien is null or public.comex_es_admin() then
    return null;
  end if;

  if tg_op = 'INSERT' then
    v_accion := 'ALTA';
    v_fila := to_jsonb(new);
  elsif tg_op = 'DELETE' then
    v_accion := 'BAJA';
    v_fila := to_jsonb(old);
  else
    v_accion := 'EDICION';
    v_fila := to_jsonb(new);
    select jsonb_object_agg(n.key, jsonb_build_array(o.value, n.value))
      into v_cambios
    from jsonb_each(to_jsonb(new)) n
    join jsonb_each(to_jsonb(old)) o on o.key = n.key
    where n.value is distinct from o.value
      and n.key not in ('semana', 'fecha', 'updated_at', 'created_at');
    if v_cambios is null then
      return null; -- re-subida sin cambios reales
    end if;
  end if;

  v_semana := v_fila ->> 'semana';
  insert into public.comex_notificaciones (usuario, accion, registro, awb, destino, vuelo, semana, cambios)
  values (
    v_quien,
    v_accion,
    v_fila ->> 'registro',
    v_fila ->> 'awb',
    v_fila ->> 'destino',
    v_fila ->> 'vuelo',
    case when v_semana ~ '^\d+(\.\d+)?$' then v_semana::numeric::int end,
    v_cambios
  );
  return null;
end;
$$;

revoke all on function public.comex_vuelos_avisar() from public, anon, authenticated;

drop trigger if exists trg_comex_vuelos_avisar on public.logistitcas_temporada;
create trigger trg_comex_vuelos_avisar
  after insert or update or delete on public.logistitcas_temporada
  for each row execute function public.comex_vuelos_avisar();

-- Sólo los ADM ven los avisos y sólo pueden marcarlos como cerrados.
alter table public.comex_notificaciones enable row level security;
revoke all on public.comex_notificaciones from anon, authenticated;
grant select on public.comex_notificaciones to authenticated;
grant update (cerrada, cerrada_por, cerrada_en) on public.comex_notificaciones to authenticated;

drop policy if exists comex_notificaciones_leer on public.comex_notificaciones;
create policy comex_notificaciones_leer on public.comex_notificaciones
  for select to authenticated
  using ((select public.comex_es_admin()));

drop policy if exists comex_notificaciones_cerrar on public.comex_notificaciones;
create policy comex_notificaciones_cerrar on public.comex_notificaciones
  for update to authenticated
  using ((select public.comex_es_admin()))
  with check ((select public.comex_es_admin()));

-- Tiempo real: el aviso le aparece al ADM en el momento (la app igual revisa cada 2 minutos).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'comex_notificaciones'
     ) then
    alter publication supabase_realtime add table public.comex_notificaciones;
  end if;
end $$;

notify pgrst, 'reload schema';

-- Consultas útiles:
--   select usuario, rol, estado from public.comex_usuarios order by usuario;
--   select * from public.comex_notificaciones order by fecha desc limit 50;
--   update public.comex_notificaciones set cerrada = true where not cerrada;   -- cerrar todos
