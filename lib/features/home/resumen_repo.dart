import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/config.dart';
import '../../core/db/base_local.dart';
import '../../core/db/filas.dart';
import '../../core/sync/servicio_sync.dart';
import 'resumen_datos.dart';

/// Resumen del menú, siempre a mano: lo leen el inicio, el panel de cada área y los desplegables.
/// Sale de la copia local (tabla `filas`), que cada pantalla renueva al leer de la nube, así el menú
/// abre al instante y funciona sin conexión.
abstract final class ResumenVivo {
  static final datos = ValueNotifier<ResumenAreas?>(null);
  static Future<void>? _enCurso;
  static bool _otraVez = false;

  /// Relee el resumen cada vez que cambia la sincronización (al subir cambios o cambiar los pendientes).
  static void seguir(ServicioSync sync) {
    var pendientes = sync.pendientes;
    var version = sync.version;
    sync.addListener(() {
      if (sync.pendientes != pendientes || sync.version != version) {
        pendientes = sync.pendientes;
        version = sync.version;
        actualizar();
      }
    });
    actualizar();
  }

  /// Vuelve a leer la base. Si ya hay una lectura en curso, deja otra pedida para cuando termine.
  static Future<void> actualizar() {
    if (_enCurso != null) {
      _otraVez = true;
      return _enCurso!;
    }
    return _enCurso = _leer().whenComplete(() {
      _enCurso = null;
      if (_otraVez) {
        _otraVez = false;
        actualizar();
      }
    });
  }

  static Future<void> _leer() async {
    try {
      final db = BaseLocal.db;
      final semana = semanaIso(DateTime.now());

      final vuelos = await db.rawQuery(
        "SELECT clave, datos FROM filas WHERE tabla = 'logistitcas_temporada' AND borrado = 0",
      );
      final vistos = <String>{};
      var despachosTemp = 0, despachosSem = 0, tarimas = 0;
      var kilos = 0.0;
      final destinos = <String>{};
      for (final f in vuelos) {
        if (!vistos.add(txt(f['clave']))) continue;
        final v = _json(f['datos']);
        if (numDe(v['temporada']).toInt() != Config.temporada) continue;
        despachosTemp++;
        if (numDe(v['semana']).toInt() != semana) continue;
        despachosSem++;
        tarimas += numDe(v['pcs']).toInt();
        kilos += numDe(v['kilos']);
        final d = txt(v['destino']).toUpperCase();
        if (d.isNotEmpty) destinos.add(d);
      }

      final programas = await db.rawQuery(
        "SELECT clave, datos FROM filas WHERE tabla = 'comex_programa_trabajo' AND borrado = 0",
      );
      final nros = <String>{}, nrosSemana = <String>{};
      for (final f in programas) {
        final p = _json(f['datos']);
        final nro = txt(p['programa_nro']).isEmpty ? txt(f['clave']) : txt(p['programa_nro']);
        nros.add(nro);
        if (numDe(p['semana']).toInt() == semana) nrosSemana.add(nro);
      }

      final pend = await db.rawQuery('SELECT tabla, COUNT(*) AS n FROM filas WHERE sincronizado = 0 GROUP BY tabla');
      final pendientes = <String, int>{};
      for (final p in pend) {
        final area = areaDeTabla(txt(p['tabla']));
        if (area != null) pendientes[area] = (pendientes[area] ?? 0) + numDe(p['n']).toInt();
      }

      datos.value = ResumenAreas(
        semanaActual: semana,
        despachosSemana: despachosSem,
        tarimasSemana: tarimas,
        kilosSemana: kilos,
        despachosTemporada: despachosTemp,
        destinosSemana: destinos.length,
        programasSemana: nrosSemana.length,
        programasTemporada: nros.length,
        pendientes: pendientes,
      );
    } catch (_) {
      // base todavía cerrada: el menú se dibuja sin números
    }
  }

  static Map<String, Object?> _json(Object? s) {
    try {
      return Map<String, Object?>.from(jsonDecode(txt(s)) as Map);
    } catch (_) {
      return const {};
    }
  }
}
