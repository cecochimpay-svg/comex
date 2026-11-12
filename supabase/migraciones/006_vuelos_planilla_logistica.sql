-- COMEX · Vuelos con el formato de la planilla de logística (TCI)
-- Ejecutar una sola vez en Supabase > SQL Editor. Se puede volver a correr sin romper nada.
--
-- La planilla de logística trae: AWB, INGRESO TCA REQUERIDO, DESTINO, RUTA, VUELO, PROFORMA,
-- ETD, CONEX, ETA, TARIMAS, PESO, TARIFA, STATUS, CNNE. No trae cliente.
--
-- Ya existían: awb, ingreso, destino, vuelo, fecha_etd1, vuelo_cnx, fecha_eta_1, pcs (tarimas),
-- kilos (peso), tarifa_kg y consignatario (CNNE). Se agregan las tres que faltaban.
--
-- El formulario de Vuelos carga solo esas columnas. CNNE es texto libre, como en la planilla.
-- Los campos viejos que no están en la planilla (cliente_final, origen, línea aérea, ULD...)
-- no se tocan al editar: los registros anteriores los conservan.

alter table public.logistitcas_temporada
  add column if not exists proforma text,
  add column if not exists ruta text,
  add column if not exists status text;

notify pgrst, 'reload schema';
