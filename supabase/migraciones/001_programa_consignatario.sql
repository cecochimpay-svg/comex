-- COMEX · Programa de trabajo: consignatario + semana real
-- Ejecutar una sola vez en Supabase > SQL Editor. Se puede volver a correr sin romper nada.

-- 1. Nueva columna: el consignatario elegido en cada bloque
alter table public.comex_programa_trabajo
  add column if not exists consignatario text;

-- 2. Completar el consignatario de los programas ya cargados,
--    solo cuando cliente + destino tienen un único consignatario (sin ambigüedad)
update public.comex_programa_trabajo p
set consignatario = cc.consignatario
from (
  select trim(cliente) as cliente, trim(destino) as destino, min(trim(consignatario)) as consignatario
  from public.clientes_consignatarios
  where activo is not false
  group by trim(cliente), trim(destino)
  having count(distinct trim(consignatario)) = 1
) cc
where p.consignatario is null
  and trim(p.cliente) = cc.cliente
  and trim(coalesce(p.destino, '')) = coalesce(cc.destino, '');

-- 3. Corregir la semana de los programas viejos (quedaban todos en 1); semana ISO como en Vuelos
update public.comex_programa_trabajo
set semana = extract(week from fecha::date)::int
where fecha is not null
  and semana is distinct from extract(week from fecha::date)::int;

-- 4. Índice para abrir, editar y copiar programas rápido
create index if not exists idx_comex_programa_trabajo_nro
  on public.comex_programa_trabajo (programa_nro);

-- 5. Que la API vea la columna nueva sin esperar
notify pgrst, 'reload schema';
