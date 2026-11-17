import 'package:sqflite_common/sqlite_api.dart';

/// Esquema SQLite local de COMEX (offline-first).
///
/// A diferencia de salvucci, COMEX trabaja contra pocas tablas de Supabase que comparte con
/// COMEX Despachos y etiquetado, así que la copia local es genérica: cada fila de la nube se guarda
/// como JSON en [filas], con su tabla, su clave y su estado:
///   sincronizado = 1  igual a la nube · 0  cambio local pendiente de subir
///   borrado      = 1  borrada en este equipo, pendiente de borrar en la nube
/// "alcance" agrupa lo que bajó con una misma consulta (p. ej. "2026|juan"), para poder reemplazarlo
/// entero en la próxima bajada sin tocar lo de otros usuarios o temporadas.
Future<void> inicializarEsquema(Database db) async {
  await db.transaction((txn) async {
    for (final sql in _tablas) {
      await txn.execute(sql);
    }
    for (final sql in _indices) {
      await txn.execute(sql);
    }
  });
}

const _tablas = [
  '''
  CREATE TABLE IF NOT EXISTS sesion_activa (
    id INTEGER PRIMARY KEY,
    usuario_id INTEGER,
    nombre_usuario TEXT,
    token TEXT,
    fecha_inicio TEXT,
    rol TEXT,
    correo TEXT
  )''',
  // Verificador local (scrypt) de la última clave validada con internet: permite entrar sin conexión.
  '''
  CREATE TABLE IF NOT EXISTS credenciales_locales (
    correo TEXT PRIMARY KEY,
    hash TEXT NOT NULL,
    usuario_json TEXT,
    actualizado TEXT
  )''',
  '''
  CREATE TABLE IF NOT EXISTS filas (
    tabla TEXT NOT NULL,
    clave TEXT NOT NULL,
    alcance TEXT NOT NULL DEFAULT '',
    datos TEXT NOT NULL,
    sincronizado INTEGER NOT NULL DEFAULT 1,
    borrado INTEGER NOT NULL DEFAULT 0,
    actualizado TEXT,
    PRIMARY KEY (tabla, clave)
  )''',
];

const _indices = [
  'CREATE INDEX IF NOT EXISTS idx_filas_alcance ON filas (tabla, alcance)',
  'CREATE INDEX IF NOT EXISTS idx_filas_pendientes ON filas (sincronizado)',
];
