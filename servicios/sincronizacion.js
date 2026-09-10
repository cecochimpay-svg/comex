const { db } = require('../data/base.js');
const { supabaseCampo } = require('./conexion.js');

function guardarVueloLocal(vuelo, usuarioActivo) {
  const regId = vuelo.registro || `REG-${Date.now()}`;
  const payload = {
    ...vuelo,
    registro: regId,
    usuario: usuarioActivo,
    sincronizado: 0
  };

  db.prepare(`INSERT INTO local_logistitcas_temporada`).run(payload);
  return payload;
}

function eliminarVueloLocal(registroId) {
  return db.prepare(`DELETE FROM local_logistitcas_temporada WHERE registro = ?`).run(registroId);
}

async function pushVuelos(usuarioActivo) {
  const resultado = { eliminados: 0, subidos: 0 };

  // 1. Borrar en Supabase
  const eliminaciones = db.prepare(`SELECT * FROM local_eliminados WHERE tabla = 'logistitcas_temporada'`).all();
  if (eliminaciones.length > 0) {
    const idsParaEliminar = eliminaciones.map(e => e.registro_id);

    let query = supabaseCampo.from('logistitcas_temporada').delete().in('registro', idsParaEliminar);
    if (usuarioActivo) {
      query = query.eq('usuario', usuarioActivo);
    }
    const { error: errDel } = await query;
    if (errDel) throw errDel;

    const idsTickets = eliminaciones.map(e => e.id);
    db.prepare(`DELETE FROM local_eliminados`).run(...idsTickets);
    resultado.eliminados = idsParaEliminar.length;
  }

  // 2. Subir altas y ediciones pendientes (sincronizado = 0)
  const pendientes = db.prepare(`SELECT * FROM local_logistitcas_temporada WHERE sincronizado = 0`).all();
  const pendientesUsuario = usuarioActivo ? pendientes.filter(x => x.usuario === usuarioActivo) : pendientes;

  if (pendientesUsuario.length > 0) {
    const payloads = pendientesUsuario.map(row => ({
      registro: row.registro,
      temporada: row.temporada,
      semana: row.semana,
      fecha: row.fecha,
      ingreso: row.ingreso,
      cliente: row.cliente,
      info: row.info,
      pcs: row.pcs,
      kilos: row.kilos,
      destino: row.destino,
      linea_aerea: row.linea_aerea,
      awb: row.awb,
      vuelo: row.vuelo,
      fecha_etd1: row.fecha_etd1,
      hora_etd1: row.hora_etd1,
      fecha_eta_1: row.fecha_eta_1,
      hora_eta1: row.hora_eta1,
      vuelo_cnx: row.vuelo_cnx,
      fecha_etd2: row.fecha_etd2,
      hora_etd2: row.hora_etd2,
      fecha_eta_2: row.fecha_eta_2,
      hora_eta2: row.hora_eta2,
      tarifa_kg: row.tarifa_kg,
      fijos: row.fijos,
      uld: row.uld,
      neta: row.neta,
      usuario: row.usuario
    }));

    const { error: errUpsert } = await supabaseCampo
      .from('logistitcas_temporada')
      .upsert(payloads, { onConflict: 'registro' });

    if (errUpsert) throw errUpsert;

    pendientesUsuario.forEach(r => {
      db.prepare(`UPDATE local_logistitcas_temporada SET sincronizado = 1 WHERE registro = ?`).run(r.registro);
    });

    resultado.subidos = pendientesUsuario.length;
  }

  return resultado;
}

async function pullVuelos(temporada, usuarioActivo) {
  let query = supabaseCampo
    .from('logistitcas_temporada')
    .select('*')
    .eq('temporada', temporada);

  if (usuarioActivo) {
    query = query.eq('usuario', usuarioActivo);
  }

  const { data, error } = await query;
  if (error) throw error;
  if (!data || data.length === 0) return 0;

  data.forEach(row => {
    db.prepare(`INSERT INTO local_logistitcas_temporada`).run({
      registro: row.registro,
      temporada: row.temporada,
      semana: row.semana,
      fecha: row.fecha,
      ingreso: row.ingreso,
      cliente: row.cliente,
      info: row.info,
      pcs: row.pcs,
      kilos: row.kilos,
      destino: row.destino,
      linea_aerea: row.linea_aerea,
      awb: row.awb,
      vuelo: row.vuelo,
      fecha_etd1: row.fecha_etd1,
      hora_etd1: row.hora_etd1,
      fecha_eta_1: row.fecha_eta_1,
      hora_eta1: row.hora_eta1,
      vuelo_cnx: row.vuelo_cnx,
      fecha_etd2: row.fecha_etd2,
      hora_etd2: row.hora_etd2,
      fecha_eta_2: row.fecha_eta_2,
      hora_eta2: row.hora_eta2,
      tarifa_kg: row.tarifa_kg,
      fijos: row.fijos,
      uld: row.uld,
      neta: row.neta,
      usuario: row.usuario,
      sincronizado: 1
    });
  });

  return data.length;
}

// Sincronizar Proyecciones de 11 días
async function sincronizarProyecciones(usuarioActivo) {
  const { data, error } = await supabaseCampo
    .from('comex_proyeccion_dias')
    .select('*')
    .eq('usuario', usuarioActivo);

  if (error) throw error;
  return data || [];
}

// Guardar o actualizar celda de proyección (Cosecha, Inspección, Carga, Ezeiza)
async function guardarProyeccionDia(payload) {
  const { error } = await supabaseCampo
    .from('comex_proyeccion_dias')
    .upsert([payload], { onConflict: 'fecha,usuario' });

  if (error) throw error;
  return true;
}

// Guardar renglones de programa de empaque
async function guardarProgramaTrabajo(renglones) {
  const { data, error } = await supabaseCampo
    .from('comex_programa_trabajo')
    .insert(renglones)
    .select();

  if (error) throw error;
  return data;
}


// Descargar proyecciones de 11 días desde Supabase y guardarlas en el JSON local
async function pullProyecciones(usuarioActivo) {
  let query = supabaseCampo.from('comex_proyeccion_dias').select('*');
  if (usuarioActivo) {
    query = query.eq('usuario', usuarioActivo);
  }

  const { data, error } = await query;
  if (error) throw error;
  if (!data || data.length === 0) return 0;

  data.forEach(row => {
    db.prepare(`INSERT INTO local_comex_proyeccion_dias`).run(row);
  });

  return data.length;
}

// Descargar programa de empaque desde Supabase al storage local
async function pullProgramaTrabajo(usuarioActivo) {
  let query = supabaseCampo.from('comex_programa_trabajo').select('*');
  if (usuarioActivo) {
    query = query.eq('usuario', usuarioActivo);
  }

  const { data, error } = await query;
  if (error) throw error;
  if (!data || data.length === 0) return 0;

  data.forEach(row => {
    db.prepare(`INSERT INTO local_comex_programa_trabajo`).run(row);
  });

  return data.length;
}

// Sincronizar Proyecciones (Sube o lee según flujo)
async function sincronizarProyecciones(usuarioActivo) {
  // 1. Descargamos de la nube
  await pullProyecciones(usuarioActivo);
  // 2. Retornamos la lista consolidada desde la base local
  return db.prepare(`SELECT * FROM local_comex_proyeccion_dias`).all();
}

// Función maestra para descargar TODO el estado desde Supabase
async function descargarTodoElEstado(temporada, usuarioActivo) {
  const vuelos = await pullVuelos(temporada, usuarioActivo);
  const proyecciones = await pullProyecciones(usuarioActivo);
  const programa = await pullProgramaTrabajo(usuarioActivo);

  return {
    vuelosDescargados: vuelos,
    proyeccionesDescargadas: proyecciones,
    programaDescargado: programa
  };
}
async function sincronizarVuelosCompleto(temporada, usuarioActivo) {
  const pushRes = await pushVuelos(usuarioActivo);
  const pullCount = await pullVuelos(temporada, usuarioActivo);
  return { ...pushRes, descargados: pullCount };
}

module.exports = {
  guardarVueloLocal,
  eliminarVueloLocal,
  pushVuelos,
  pullVuelos,
  sincronizarVuelosCompleto,
  sincronizarProyecciones,
  pullProyecciones,
  pullProgramaTrabajo,
  guardarProyeccionDia,
  guardarProgramaTrabajo,
  descargarTodoElEstado
};