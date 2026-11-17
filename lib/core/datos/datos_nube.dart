import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/base_local.dart';
import '../db/filas.dart';
import '../red.dart';

/// Resultado de una lectura: las filas y si vinieron de la copia local (sin conexión).
class Lectura {
  const Lectura(this.filas, {required this.offline});
  final List<Fila> filas;
  final bool offline;
}

/// Acceso a las tablas de Supabase con copia local (offline-first), igual que hacía la versión Electron
/// con data/base.js, pero en SQLite y para cualquier tabla:
///   - [leer] trae de la nube y renueva la copia; sin red devuelve la copia.
///   - [guardar] / [borrar] van directo a la nube; sin red quedan pendientes y se suben al sincronizar.
/// Los cambios pendientes de este equipo siempre se ven por encima de lo que bajó de la nube.
abstract final class DatosNube {
  /// Cliente de la nube (los tests ponen uno propio).
  @visibleForTesting
  static SupabaseClient Function() cliente = () => Supabase.instance.client;

  static SupabaseClient get _nube => cliente();

  /// Tiempo máximo de una lectura antes de usar la copia local. Sin esto, sin internet el cliente
  /// de Supabase reintenta solo y tarda ~15 s en fallar (la pantalla quedaba cargando).
  static const limiteLectura = Duration(seconds: 5);

  /// Tiempo máximo de una escritura antes de dejarla pendiente. Upsert y borrado se pueden repetir sin
  /// efecto doble, así que si la nube igual la recibe tarde, al sincronizar no pasa nada.
  static const limiteEscritura = Duration(seconds: 12);
  static Database get _db => BaseLocal.db;

  /// [alcance] identifica qué parte de la tabla trae la consulta (p. ej. "2026|todos"), para reemplazar
  /// sólo eso en la copia local.
  static Future<Lectura> leer({
    required String tabla,
    required String clave,
    required String alcance,
    required Future<List<Map<String, dynamic>>> Function(SupabaseClient nube) consulta,
    String Function(Map<String, dynamic> fila)? claveDe,
  }) async {
    List<Map<String, dynamic>> remotas;
    try {
      remotas = await consulta(_nube).timeout(limiteLectura);
    } catch (e) {
      if (!esErrorDeRed(e)) rethrow;
      return Lectura(await _copia(tabla, alcance), offline: true);
    }

    final ahora = DateTime.now().toIso8601String();
    await _db.transaction((txn) async {
      await txn.delete('filas', where: 'tabla = ? AND alcance = ? AND sincronizado = 1', whereArgs: [tabla, alcance]);
      final lote = txn.batch();
      for (final f in remotas) {
        // [claveDe]: clave local de tablas con clave compuesta (p. ej. "fecha|usuario").
        final k = claveDe?.call(f) ?? txt(f[clave]);
        if (k.isEmpty) continue;
        // Si esa fila ya estaba (bajada con otro alcance) pasa a este; un cambio local pendiente se conserva.
        lote.rawInsert(
          'INSERT INTO filas (tabla, clave, alcance, datos, sincronizado, borrado, actualizado) '
          'VALUES (?, ?, ?, ?, 1, 0, ?) '
          'ON CONFLICT (tabla, clave) DO UPDATE SET alcance = excluded.alcance, datos = excluded.datos, '
          'actualizado = excluded.actualizado WHERE filas.sincronizado = 1',
          [tabla, k, alcance, jsonEncode(f, toEncodable: (o) => '$o'), ahora],
        );
      }
      await lote.commit(noResult: true);
    });
    return Lectura(await _copia(tabla, alcance), offline: false);
  }

  /// Guarda (alta o edición) en la nube. Devuelve false si quedó pendiente por falta de conexión.
  /// A la nube va sólo [fila] (las columnas que se tocaron); la copia local guarda [copiaLocal]
  /// (la fila completa, con lo que ya tenía) para que la pantalla la siga mostrando entera.
  /// Si la nube no tiene alguna columna (migración sin correr), se guarda sin ella y se avisa en [omitidas].
  static Future<bool> guardar({
    required String tabla,
    required String clave,
    required String alcance,
    required Map<String, Object?> fila,
    Map<String, Object?>? copiaLocal,
    List<String>? omitidas,
    String? valorClave,
  }) async {
    // [valorClave]: clave local cuando no sale de una sola columna (clave compuesta, como
    // clave = 'fecha,usuario', que también es el onConflict) o la fila nueva todavía no tiene id
    // (p. ej. 'tmp-…': se inserta y la próxima lectura la reemplaza por la fila con su id).
    final k = valorClave ?? txt(fila[clave]);
    if (k.isEmpty) throw ArgumentError('La fila no tiene $clave.');
    final local = _sinInternos({...?copiaLocal, ...fila});
    try {
      await _subirFila(tabla, clave, _sinInternos(fila), omitidas);
      await _anotar(tabla, k, alcance, local, sincronizado: 1);
      return true;
    } catch (e) {
      if (!esErrorDeRed(e)) rethrow;
      await _anotar(tabla, k, alcance, local, sincronizado: 0);
      return false;
    }
  }

  /// Saca los campos que agrega la app (empiezan con "_", p. ej. "_sincronizado").
  static Map<String, Object?> _sinInternos(Map<String, Object?> f) =>
      {for (final e in f.entries) if (!e.key.startsWith('_')) e.key: e.value};

  /// Borra en la nube. Devuelve false si quedó pendiente por falta de conexión.
  static Future<bool> borrar({required String tabla, required String clave, required String valor}) async {
    try {
      await _nube.from(tabla).delete().eq(clave, valor).timeout(limiteEscritura);
      await _db.delete('filas', where: 'tabla = ? AND clave = ?', whereArgs: [tabla, valor]);
      return true;
    } catch (e) {
      if (!esErrorDeRed(e)) rethrow;
      await _db.update(
        'filas',
        {'borrado': 1, 'sincronizado': 0, 'actualizado': DateTime.now().toIso8601String()},
        where: 'tabla = ? AND clave = ?',
        whereArgs: [tabla, valor],
      );
      return false;
    }
  }

  /// Quita una fila sólo de la copia local (p. ej. una alta 'tmp-…' que se reemplaza antes de subir).
  static Future<void> descartarLocal({required String tabla, required String clave}) =>
      _db.delete('filas', where: 'tabla = ? AND clave = ?', whereArgs: [tabla, clave]);

  static Future<int> pendientes() async {
    final r = await _db.rawQuery('SELECT COUNT(*) AS n FROM filas WHERE sincronizado = 0');
    return (r.first['n'] as num?)?.toInt() ?? 0;
  }

  /// Sube altas, ediciones y borrados pendientes. [claves] dice la columna clave de cada tabla.
  /// Devuelve cuántos subieron y cuántos fallaron (los que fallan se reintentan la próxima vez).
  static Future<({int subidos, int fallidos})> subirPendientes(Map<String, String> claves) async {
    final pend = await _db.rawQuery('SELECT * FROM filas WHERE sincronizado = 0');
    var subidos = 0, fallidos = 0;
    for (final p in pend) {
      final tabla = txt(p['tabla']);
      final k = txt(p['clave']);
      final columna = claves[tabla];
      if (columna == null) continue;
      try {
        if ('${p['borrado']}' == '1') {
          await _nube.from(tabla).delete().eq(columna, k).timeout(limiteEscritura);
          await _db.delete('filas', where: 'tabla = ? AND clave = ?', whereArgs: [tabla, k]);
        } else {
          final fila = _sinInternos(Map<String, Object?>.from(jsonDecode(txt(p['datos'])) as Map));
          await _subirFila(tabla, columna, fila, null);
          await _db.update('filas', {'sincronizado': 1}, where: 'tabla = ? AND clave = ?', whereArgs: [tabla, k]);
        }
        subidos++;
      } catch (e) {
        if (esErrorDeRed(e)) rethrow; // sin red no tiene sentido seguir
        fallidos++;
      }
    }
    return (subidos: subidos, fallidos: fallidos);
  }

  // ---------------------------------------------------------------------------

  static final _columnaFaltante = RegExp(r"Could not find the '([A-Za-z0-9_ ]+)' column");

  static Future<void> _subirFila(String tabla, String clave, Map<String, Object?> fila, List<String>? omitidas) async {
    final datos = Map<String, Object?>.from(fila);
    for (var intento = 0; intento < 8; intento++) {
      try {
        await _nube.from(tabla).upsert(datos, onConflict: clave).timeout(limiteEscritura);
        return;
      } on PostgrestException catch (e) {
        final m = _columnaFaltante.firstMatch(e.message);
        if (m == null || !datos.containsKey(m[1])) rethrow;
        datos.remove(m[1]);
        omitidas?.add(m[1]!);
      }
    }
  }

  static Future<void> _anotar(String tabla, String k, String alcance, Map<String, Object?> fila,
      {required int sincronizado}) async {
    await _db.rawInsert(
      'INSERT OR REPLACE INTO filas (tabla, clave, alcance, datos, sincronizado, borrado, actualizado) '
      'VALUES (?, ?, ?, ?, ?, 0, ?)',
      [tabla, k, alcance, jsonEncode(fila, toEncodable: (o) => '$o'), sincronizado, DateTime.now().toIso8601String()],
    );
  }

  static Future<List<Fila>> _copia(String tabla, String alcance) async {
    final r = await _db.rawQuery(
      'SELECT clave, datos, sincronizado FROM filas WHERE tabla = ? AND alcance = ? AND borrado = 0',
      [tabla, alcance],
    );
    return [
      for (final x in r)
        {
          ...Map<String, Object?>.from(jsonDecode(txt(x['datos'])) as Map),
          '_sincronizado': x['sincronizado'],
          '_clave': x['clave'],
        },
    ];
  }
}
