import 'package:flutter/material.dart';

import '../../core/db/filas.dart';
import '../../core/tema/paleta.dart';
import '../home/resumen_datos.dart' show semanaIso;

/// Despacho aéreo de `logistitcas_temporada` con las columnas de la planilla de logística (TCI):
/// AWB · Ingreso TCA · Destino · Ruta · Vuelo · Proforma · ETD · Conex · ETA · Tarimas · Peso ·
/// Tarifa · Status · CNNE. Los campos viejos (línea aérea, origen, cliente final…) se conservan.
class Vuelo {
  Vuelo(this.f);

  final Fila f;

  String get registro => txt(f['registro']);
  int get semana => numDe(f['semana']).toInt();
  String get usuario => txt(f['usuario']);
  String get awb => txt(f['awb']);
  String get ingreso => _fecha(f['ingreso']);
  String get destino => txt(f['destino']).toUpperCase();
  String get vuelo => txt(f['vuelo']);
  String get proforma => txt(f['proforma']);
  String get conex => txt(f['vuelo_cnx']);
  String get etdFecha => _fecha(f['fecha_etd1']);
  String get etdHora => _hora(f['hora_etd1']);
  int get tarimas => numDe(f['pcs']).toInt();
  double get peso => numDe(f['kilos']);
  String get tarifa => txt(f['tarifa_kg']);
  String get status => txt(f['status']).toUpperCase();
  String get cnne => txt(f['consignatario']);
  String get lineaAerea => txt(f['linea_aerea']);

  /// Pendiente de subir (cargado sin conexión).
  bool get pendiente => '${f['_sincronizado'] ?? 1}' == '0';

  /// Ruta cargada a mano o, en los registros viejos, origen-destino.
  String get ruta {
    final r = txt(f['ruta']).toUpperCase();
    if (r.isNotEmpty) return r;
    return [txt(f['origen']).toUpperCase(), destino].where((x) => x.isNotEmpty).join('-');
  }

  /// La ETA de la planilla es la llegada final: en registros viejos con conexión, la del tramo 2.
  bool get etaEnTramo2 => _fecha(f['fecha_eta 2'] ?? f['fecha_eta_2']).isNotEmpty;
  String get etaFecha => etaEnTramo2 ? _fecha(f['fecha_eta 2'] ?? f['fecha_eta_2']) : _fecha(f['fecha_eta_1']);
  String get etaHora => etaEnTramo2 ? _hora(f['hora_eta2']) : _hora(f['hora_eta1']);

  /// Texto donde busca el buscador.
  String get textoBusqueda => [
    awb, destino, ruta, vuelo, proforma, conex, status, cnne, usuario, tarifa, lineaAerea,
  ].join(' ').toLowerCase();

  static String _fecha(Object? v) {
    final s = txt(v);
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  static String _hora(Object? v) {
    final s = txt(v);
    return s.length >= 5 ? s.substring(0, 5) : s;
  }
}

/// Estados del despacho con su LED, en el orden en que avanza la carga.
class EstadoDespacho {
  const EstadoDespacho(this.nombre, this._claro, this._noche);

  final String nombre;
  final int _claro;
  final int _noche;

  Color get color => Paleta.dual(_claro, _noche);
}

const estadosDespacho = <EstadoDespacho>[
  EstadoDespacho('PROGRAMADO', 0xFF3B82F6, 0xFF6BAEF2),
  EstadoDespacho('CONFIRMADO', 0xFF8B5CF6, 0xFFB5A6E3),
  EstadoDespacho('EN TCA', 0xFFF59E0B, 0xFFF2C25C),
  EstadoDespacho('VOLADO', 0xFF10B981, 0xFF5FD3A6),
  EstadoDespacho('ARRIBADO', 0xFF0F766E, 0xFF4FB8AE),
  EstadoDespacho('CANCELADO', 0xFFEF4444, 0xFFF07470),
];

/// Color del LED de un status (gris si es uno escrito a mano que no está en la lista).
Color colorStatus(String status) {
  final s = status.trim().toUpperCase();
  for (final e in estadosDespacho) {
    if (e.nombre == s) return e.color;
  }
  return Paleta.tintaTenue;
}

/// Semana de la planilla: por ETD; si todavía no hay ETD, por ingreso TCA; si no, hoy.
int semanaDeDespacho({String etd = '', String ingreso = ''}) {
  final base = DateTime.tryParse(etd.isNotEmpty ? etd : ingreso) ?? DateTime.now();
  return semanaIso(base);
}

/// Semanas con despachos (de la más nueva a la más vieja) y cuántos tiene cada una.
List<(int semana, int despachos, int tarimas)> semanasDe(List<Vuelo> vuelos) {
  final porSemana = <int, (int, int)>{};
  for (final v in vuelos) {
    if (v.semana <= 0) continue;
    final (n, t) = porSemana[v.semana] ?? (0, 0);
    porSemana[v.semana] = (n + 1, t + v.tarimas);
  }
  final claves = porSemana.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final s in claves) (s, porSemana[s]!.$1, porSemana[s]!.$2)];
}

/// Filtros de la pantalla: semana elegida, status y texto libre.
class FiltrosVuelos {
  const FiltrosVuelos({this.semana, this.status, this.texto = ''});

  final int? semana;
  final String? status;
  final String texto;

  bool get hayFiltros => status != null || texto.trim().isNotEmpty;

  List<Vuelo> aplicar(List<Vuelo> vuelos) {
    final q = texto.trim().toLowerCase();
    final lista = [
      for (final v in vuelos)
        if ((semana == null || v.semana == semana) &&
            (status == null || v.status == status) &&
            (q.isEmpty || v.textoBusqueda.contains(q)))
          v,
    ];
    // Como la planilla: por ETD (los que no tienen ETD, al final) y después por AWB.
    lista.sort((a, b) {
      final ea = a.etdFecha.isEmpty ? '9999' : '${a.etdFecha} ${a.etdHora}';
      final eb = b.etdFecha.isEmpty ? '9999' : '${b.etdFecha} ${b.etdHora}';
      final c = ea.compareTo(eb);
      return c != 0 ? c : a.awb.compareTo(b.awb);
    });
    return lista;
  }

  FiltrosVuelos copiar({int? semana, bool sinSemana = false, String? status, bool sinStatus = false, String? texto}) =>
      FiltrosVuelos(
        semana: sinSemana ? null : (semana ?? this.semana),
        status: sinStatus ? null : (status ?? this.status),
        texto: texto ?? this.texto,
      );
}

/// Fecha AAAA-MM-DD a DD/MM (corta, para la tabla).
String fechaTabla(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  return m == null ? (iso.isEmpty ? '—' : iso) : '${m[3]}/${m[2]}';
}

/// Tarifa como se muestra y se guarda ("USD 3,10"); vacía = null.
String? normalizarTarifa(String texto) {
  final limpio = texto.replaceFirst(RegExp(r'^USD\s*', caseSensitive: false), '').trim();
  return limpio.isEmpty ? null : 'USD $limpio';
}
