-- COMEX · Vuelos: para quién es cada despacho y desde dónde sale
-- Ejecutar una sola vez en Supabase > SQL Editor. Se puede volver a correr sin romper nada.
--
-- "cliente" sigue siendo CECO (lo que ve logística hoy). Se agregan:
--   cliente_final  -> el cliente de CECO al que va la fruta
--   consignatario  -> a quién se consigna (clave cuando el cliente tiene 2 o más)
--   origen         -> aeropuerto de salida (EZE, NQN, MDZ...)

alter table public.logistitcas_temporada
  add column if not exists cliente_final text,
  add column if not exists consignatario text,
  add column if not exists origen text;

notify pgrst, 'reload schema';
