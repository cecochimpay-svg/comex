import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'esquema.dart';
import 'fabrica.dart';

/// Base SQLite local (offline-first). Mismo archivo y esquema que la versión de escritorio.
abstract final class BaseLocal {
  static const nombreArchivo = 'comex_local.db';

  static Database? _db;

  static Database get db {
    final d = _db;
    if (d == null) throw StateError('La base local no está abierta.');
    return d;
  }

  static Future<void> abrir() async {
    if (_db != null) return;
    final db = await abrirBaseNativa(nombreArchivo);
    if (!kIsWeb) {
      try {
        await db.rawQuery('PRAGMA journal_mode = WAL');
      } catch (_) {
        // Algunos motores no lo permiten: se sigue con el modo por defecto.
      }
    }
    await inicializarEsquema(db);
    _db = db;
  }

  /// Tests: usa una base ya abierta (p. ej. en memoria con FFI) con el esquema inicializado.
  @visibleForTesting
  static Future<void> usar(Database db) async {
    await inicializarEsquema(db);
    _db = db;
  }

  /// Columnas reales de una tabla local (para conciliar lo que baja de la nube).
  static Future<List<String>> columnas(String tabla) async {
    final info = await db.rawQuery('PRAGMA table_info("$tabla")');
    return [for (final c in info) '${c['name']}'];
  }
}
