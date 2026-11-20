import 'dart:typed_data';

import '../../core/auth/sesion.dart';
import '../../core/config.dart';
import '../../core/datos/datos_nube.dart';
import '../../core/db/filas.dart';
import '../../core/formato.dart';
import '../../core/importar/lector_xlsx.dart';
import '../../core/red.dart';
import 'vuelos_datos.dart';
import 'vuelos_repo.dart';

/// Importación de la planilla de despachos que manda cada operador (Excel .xlsx).
///
/// Las columnas se reconocen por el nombre del encabezado, no por la posición, así sirve para las
/// planillas de todos: la de logística TCI (AWB · INGRESO TCA REQUERIDO · DESTINO · RUTA · VUELO ·
/// PROFORMA · ETD · CONEX · ETA · TARIMAS · PESO · TARIFA · STATUS · CNNE) y la completa de Jetcargo
/// (SEMANA · CLIENTE · CONSIGNEE · PALLETS · KILOS · LINEA AEREA · FECHA ETD1 · HORA ETD1 · VUELO CNX…).
///
/// Cada fila se busca entre los despachos del usuario por AWB (si un AWB se repite, se emparejan en
/// orden). Si ya está, se actualizan sólo las columnas que cambiaron; si no, se crea. Una celda vacía
/// no borra lo que ya estaba cargado, y nada se elimina.

/// Datos de la planilla que se pueden importar, con su columna en `logistitcas_temporada`.
enum CampoPlanilla {
  awb('AWB'),
  ingreso('Ingreso TCA'),
  destino('Destino'),
  ruta('Ruta'),
  vuelo('Vuelo'),
  proforma('Proforma'),
  etd('ETD'),
  etdHora('Hora ETD'),
  conex('Conex'),
  etd2('ETD conex'),
  etd2Hora('Hora ETD conex'),
  eta('ETA'),
  etaHora('Hora ETA'),
  eta2('ETA conex'),
  eta2Hora('Hora ETA conex'),
  tarimas('Tarimas'),
  peso('Peso'),
  tarifa('Tarifa'),
  fijos('Fijos / AWB'),
  status('Status'),
  cnne('CNNE'),
  cliente('Cliente'),
  lineaAerea('Línea aérea');

  const CampoPlanilla(this.etiqueta);
  final String etiqueta;
}

/// Encabezados reconocidos (ya normalizados con [normalizarEncabezado]) y su prioridad: si una
/// planilla trae dos columnas para el mismo dato, gana la de prioridad más baja
/// (p. ej. Jetcargo trae "TARIFA /KG" con el total y "TARIFA" sin el fuel).
const _sinonimos = <String, (CampoPlanilla, int)>{
  'AWB': (CampoPlanilla.awb, 0),
  'MAWB': (CampoPlanilla.awb, 0),
  'NRO AWB': (CampoPlanilla.awb, 0),
  'GUIA': (CampoPlanilla.awb, 1),
  'INGRESO TCA REQUERIDO': (CampoPlanilla.ingreso, 0),
  'INGRESO TCA': (CampoPlanilla.ingreso, 0),
  'INGRESO': (CampoPlanilla.ingreso, 1),
  'FECHA INGRESO': (CampoPlanilla.ingreso, 1),
  'DESTINO': (CampoPlanilla.destino, 0),
  'DESTINATION': (CampoPlanilla.destino, 0),
  'DEST': (CampoPlanilla.destino, 1),
  'RUTA': (CampoPlanilla.ruta, 0),
  'ROUTING': (CampoPlanilla.ruta, 0),
  'ROUTE': (CampoPlanilla.ruta, 0),
  'VUELO': (CampoPlanilla.vuelo, 0),
  'VUELO1': (CampoPlanilla.vuelo, 0),
  'FLIGHT': (CampoPlanilla.vuelo, 0),
  'NRO VUELO': (CampoPlanilla.vuelo, 1),
  'PROFORMA': (CampoPlanilla.proforma, 0),
  'PF': (CampoPlanilla.proforma, 0),
  'REF': (CampoPlanilla.proforma, 1),
  'REFERENCIA': (CampoPlanilla.proforma, 1),
  'ETD': (CampoPlanilla.etd, 0),
  'ETD1': (CampoPlanilla.etd, 0),
  'FECHA ETD': (CampoPlanilla.etd, 0),
  'FECHA ETD1': (CampoPlanilla.etd, 0),
  'HORA ETD': (CampoPlanilla.etdHora, 0),
  'HORA ETD1': (CampoPlanilla.etdHora, 0),
  'CONEX': (CampoPlanilla.conex, 0),
  'VUELO CNX': (CampoPlanilla.conex, 0),
  'CNX': (CampoPlanilla.conex, 0),
  'CONEXION': (CampoPlanilla.conex, 0),
  'VUELO CONEXION': (CampoPlanilla.conex, 0),
  'VUELO2': (CampoPlanilla.conex, 1),
  'ETD2': (CampoPlanilla.etd2, 0),
  'FECHA ETD2': (CampoPlanilla.etd2, 0),
  'HORA ETD2': (CampoPlanilla.etd2Hora, 0),
  'ETA': (CampoPlanilla.eta, 0),
  'ETA1': (CampoPlanilla.eta, 0),
  'FECHA ETA': (CampoPlanilla.eta, 0),
  'FECHA ETA1': (CampoPlanilla.eta, 0),
  'HORA ETA': (CampoPlanilla.etaHora, 0),
  'HORA ETA1': (CampoPlanilla.etaHora, 0),
  'ETA2': (CampoPlanilla.eta2, 0),
  'FECHA ETA2': (CampoPlanilla.eta2, 0),
  'HORA ETA2': (CampoPlanilla.eta2Hora, 0),
  'TARIMAS': (CampoPlanilla.tarimas, 0),
  'PALLETS': (CampoPlanilla.tarimas, 0),
  'PALLET': (CampoPlanilla.tarimas, 0),
  'POSICIONES': (CampoPlanilla.tarimas, 1),
  'PCS': (CampoPlanilla.tarimas, 1),
  'PESO': (CampoPlanilla.peso, 0),
  'PESO KG': (CampoPlanilla.peso, 0),
  'KILOS': (CampoPlanilla.peso, 0),
  'KG': (CampoPlanilla.peso, 1),
  'TARIFA KG': (CampoPlanilla.tarifa, 0),
  'TARIFA X KG': (CampoPlanilla.tarifa, 0),
  'TARIFA POR KG': (CampoPlanilla.tarifa, 0),
  'TARIFA': (CampoPlanilla.tarifa, 1),
  'RATE': (CampoPlanilla.tarifa, 1),
  'FIJOS AWB': (CampoPlanilla.fijos, 0),
  'STATUS': (CampoPlanilla.status, 0),
  'ESTADO': (CampoPlanilla.status, 0),
  'CNNE': (CampoPlanilla.cnne, 0),
  'CNEE': (CampoPlanilla.cnne, 0),
  'CONSIGNEE': (CampoPlanilla.cnne, 0),
  'CONSIGNATARIO': (CampoPlanilla.cnne, 0),
  'CLIENTE': (CampoPlanilla.cliente, 0),
  'LINEA AEREA': (CampoPlanilla.lineaAerea, 0),
  'AEROLINEA': (CampoPlanilla.lineaAerea, 0),
  'AIRLINE': (CampoPlanilla.lineaAerea, 0),
  'CIA AEREA': (CampoPlanilla.lineaAerea, 1),
};

/// Status en inglés (o abreviados) que mandan algunos operadores -> los de la lista de COMEX.
const _statusEquivalentes = <String, String>{
  'BOOKED': 'CONFIRMADO',
  'CONFIRMED': 'CONFIRMADO',
  'CONF': 'CONFIRMADO',
  'FLOWN': 'VOLADO',
  'DEPARTED': 'VOLADO',
  'ARRIVED': 'ARRIBADO',
  'CANCELLED': 'CANCELADO',
  'CANCELED': 'CANCELADO',
  'CANCELADA': 'CANCELADO',
  'PROGRAMADA': 'PROGRAMADO',
};

/// "Fecha ETA 1", "TARIFA /KG", "Línea aérea" -> "FECHA ETA1", "TARIFA KG", "LINEA AEREA".
String normalizarEncabezado(Object? v) {
  var s = (v is String ? v : '').toUpperCase();
  const acentos = {'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N'};
  acentos.forEach((a, b) => s = s.replaceAll(a, b));
  s = s.replaceAll(RegExp(r'[^A-Z0-9]+'), ' ').trim();
  return s.replaceAllMapped(RegExp(r'([A-Z]) (\d)\b'), (m) => '${m[1]}${m[2]}');
}

// ─────────────────────────────── Lectura ───────────────────────────────

/// Una fila de la planilla ya traducida a columnas de `logistitcas_temporada`.
class FilaPlanilla {
  FilaPlanilla(this.numero);

  /// Número de fila en el Excel (como lo ve el usuario).
  final int numero;
  final datos = <String, Object?>{};
  final avisos = <String>[];

  /// ETA sin tramo definido (planilla TCI): va al tramo 2 si el despacho ya la tenía ahí.
  String? etaFecha;
  String? etaHora;

  String get awb => txt(datos['awb']);
  String get destino => txt(datos['destino']);
}

/// Resultado de leer la planilla.
class PlanillaLeida {
  const PlanillaLeida({
    required this.hoja,
    required this.filaEncabezado,
    required this.columnas,
    required this.filas,
    required this.ignoradas,
  });

  final String hoja;
  final int filaEncabezado;

  /// Datos reconocidos, en el orden de la planilla.
  final List<CampoPlanilla> columnas;
  final List<FilaPlanilla> filas;

  /// Filas vacías o bandas "WEEK 46 / 2026" que se saltearon.
  final int ignoradas;
}

/// Lee el .xlsx y arma las filas. Lanza [ArchivoInvalido] con el motivo si no se puede usar.
PlanillaLeida leerPlanillaVuelos(Uint8List bytes) {
  final hojas = leerXlsx(bytes);
  ({HojaXlsx hoja, int fila, Map<CampoPlanilla, int> mapa})? mejor;
  for (final h in hojas) {
    final e = _buscarEncabezado(h.filas);
    if (e != null && (mejor == null || e.mapa.length > mejor.mapa.length)) {
      mejor = (hoja: h, fila: e.fila, mapa: e.mapa);
    }
  }
  if (mejor == null) {
    throw const ArchivoInvalido(
      'No encontré la fila de títulos. La planilla tiene que tener una fila con columnas como '
      'AWB, DESTINO, VUELO, ETD, PALLETS / TARIMAS, KILOS / PESO.',
    );
  }

  final mapa = mejor.mapa;
  final filas = <FilaPlanilla>[];
  var ignoradas = 0;
  final datosFilas = mejor.hoja.filas;
  for (var i = mejor.fila + 1; i < datosFilas.length; i++) {
    final celdas = datosFilas[i];
    Object? celda(CampoPlanilla c) {
      final col = mapa[c];
      return col == null || col >= celdas.length ? null : celdas[col];
    }

    if (_esFilaIgnorable(celdas, celda, mapa)) {
      if (celdas.any((c) => c != null)) ignoradas++;
      continue;
    }
    filas.add(_traducir(i + 1, celda, mapa));
  }
  final columnas = mapa.keys.toList()..sort((a, b) => mapa[a]!.compareTo(mapa[b]!));
  return PlanillaLeida(
    hoja: mejor.hoja.nombre,
    filaEncabezado: mejor.fila + 1,
    columnas: columnas,
    filas: filas,
    ignoradas: ignoradas,
  );
}

({int fila, Map<CampoPlanilla, int> mapa})? _buscarEncabezado(List<List<Object?>> filas) {
  ({int fila, Map<CampoPlanilla, int> mapa})? mejor;
  for (var i = 0; i < filas.length && i < 40; i++) {
    final mapa = <CampoPlanilla, int>{};
    final prioridad = <CampoPlanilla, int>{};
    for (var c = 0; c < filas[i].length; c++) {
      final s = _sinonimos[normalizarEncabezado(filas[i][c])];
      if (s == null) continue;
      final (campo, p) = s;
      if (!mapa.containsKey(campo) || p < prioridad[campo]!) {
        mapa[campo] = c;
        prioridad[campo] = p;
      }
    }
    final clave = mapa.containsKey(CampoPlanilla.awb) ||
        mapa.containsKey(CampoPlanilla.vuelo) ||
        mapa.containsKey(CampoPlanilla.destino);
    if (mapa.length >= 3 && clave && (mejor == null || mapa.length > mejor.mapa.length)) {
      mejor = (fila: i, mapa: mapa);
    }
  }
  return mejor;
}

/// Filas vacías, bandas "WEEK 46 / 2026" y títulos repetidos.
bool _esFilaIgnorable(List<Object?> celdas, Object? Function(CampoPlanilla) celda, Map<CampoPlanilla, int> mapa) {
  final llenas = celdas.where((c) => c != null).toList();
  if (llenas.isEmpty) return true;
  if (llenas.length <= 2 && llenas.first is String && RegExp(r'^\s*(WEEK|SEMANA)\b', caseSensitive: false).hasMatch(llenas.first as String)) {
    return true;
  }
  var titulos = 0;
  for (final e in mapa.entries) {
    final s = _sinonimos[normalizarEncabezado(celda(e.key))];
    if (s != null && s.$1 == e.key) titulos++;
  }
  if (titulos >= 3) return true;
  const claves = [CampoPlanilla.awb, CampoPlanilla.vuelo, CampoPlanilla.destino, CampoPlanilla.tarimas, CampoPlanilla.peso];
  return claves.every((c) => _texto(celda(c)).isEmpty);
}

FilaPlanilla _traducir(int numero, Object? Function(CampoPlanilla) celda, Map<CampoPlanilla, int> mapa) {
  final f = FilaPlanilla(numero);
  final d = f.datos;

  void texto(CampoPlanilla c, String columna, {bool mayusculas = false}) {
    final t = _texto(celda(c));
    if (t.isNotEmpty) d[columna] = mayusculas ? t.toUpperCase() : t;
  }

  /// Fecha (y la hora, si la celda la trae y no hay columna de hora aparte).
  (String?, String?) fechaHora(CampoPlanilla c, CampoPlanilla? hora) {
    final v = celda(c);
    if (_texto(v).isEmpty) return (null, null);
    final (fecha, h) = leerFecha(v);
    if (fecha == null) f.avisos.add('${c.etiqueta}: no entiendo la fecha "${_texto(v)}"');
    String? horaFinal = h;
    if (hora != null && mapa.containsKey(hora)) {
      final vh = celda(hora);
      horaFinal = _texto(vh).isEmpty ? null : leerHora(vh);
      if (_texto(vh).isNotEmpty && horaFinal == null) f.avisos.add('${hora.etiqueta}: no entiendo la hora "${_texto(vh)}"');
    }
    return (fecha, horaFinal);
  }

  texto(CampoPlanilla.awb, 'awb');
  texto(CampoPlanilla.destino, 'destino', mayusculas: true);
  texto(CampoPlanilla.ruta, 'ruta', mayusculas: true);
  texto(CampoPlanilla.vuelo, 'vuelo', mayusculas: true);
  texto(CampoPlanilla.proforma, 'proforma');
  texto(CampoPlanilla.conex, 'vuelo_cnx', mayusculas: true);
  texto(CampoPlanilla.cnne, 'consignatario');
  texto(CampoPlanilla.cliente, 'cliente', mayusculas: true);
  texto(CampoPlanilla.lineaAerea, 'linea_aerea', mayusculas: true);

  final (ingreso, _) = fechaHora(CampoPlanilla.ingreso, null);
  if (ingreso != null) d['ingreso'] = ingreso;

  final (etd, etdH) = fechaHora(CampoPlanilla.etd, CampoPlanilla.etdHora);
  if (etd != null) d['fecha_etd1'] = etd;
  if (etdH != null) d['hora_etd1'] = etdH;

  final (etd2, etd2H) = fechaHora(CampoPlanilla.etd2, CampoPlanilla.etd2Hora);
  if (etd2 != null) d['fecha_etd2'] = etd2;
  if (etd2H != null) d['hora_etd2'] = etd2H;

  final (eta2, eta2H) = fechaHora(CampoPlanilla.eta2, CampoPlanilla.eta2Hora);
  if (eta2 != null) d['fecha_eta_2'] = eta2;
  if (eta2H != null) d['hora_eta2'] = eta2H;

  final (eta, etaH) = fechaHora(CampoPlanilla.eta, CampoPlanilla.etaHora);
  if (mapa.containsKey(CampoPlanilla.eta2)) {
    // Planilla con los dos tramos (Jetcargo): cada ETA va a su columna.
    if (eta != null) d['fecha_eta_1'] = eta;
    if (etaH != null) d['hora_eta1'] = etaH;
  } else {
    f.etaFecha = eta;
    f.etaHora = etaH;
  }

  for (final (c, columna) in [(CampoPlanilla.tarimas, 'pcs'), (CampoPlanilla.peso, 'kilos')]) {
    final v = celda(c);
    if (_texto(v).isEmpty) continue;
    final n = leerNumero(v);
    if (n == null) {
      f.avisos.add('${c.etiqueta}: no es un número ("${_texto(v)}")');
    } else {
      d[columna] = n.round();
    }
  }

  final tarifa = leerDinero(celda(CampoPlanilla.tarifa));
  if (tarifa != null) d['tarifa_kg'] = tarifa;
  final fijos = leerDinero(celda(CampoPlanilla.fijos));
  if (fijos != null) d['fijos'] = fijos;

  final status = _texto(celda(CampoPlanilla.status)).toUpperCase();
  if (status.isNotEmpty) d['status'] = _statusEquivalentes[status] ?? status;

  return f;
}

// ─────────────────────────────── Valores ───────────────────────────────

String _texto(Object? v) => switch (v) {
  null => '',
  double n when n == n.roundToDouble() && n.abs() < 1e15 => '${n.toInt()}',
  DateTime d => fechaIso(d),
  _ => '$v'.trim(),
};

/// Fecha de una celda: fecha de Excel, número de serie o texto (21/11/2026, 21-11-26, 2026-11-21,
/// con hora opcional). Devuelve (AAAA-MM-DD, HH:MM si traía una hora distinta de 00:00).
(String?, String?) leerFecha(Object? v) {
  if (v is DateTime) return (fechaIso(v), _horaDe(v));
  if (v is double) {
    if (v > 20000 && v < 80000) return leerFecha(fechaDeSerie(v));
    return (null, null);
  }
  final s = _texto(v);
  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?').firstMatch(s);
  if (m != null) {
    return _armarFecha(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), m[4], m[5]);
  }
  m = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})(?:\s+(\d{1,2})[:.](\d{2}))?').firstMatch(s);
  if (m != null) {
    var anio = int.parse(m[3]!);
    if (anio < 100) anio += 2000;
    return _armarFecha(anio, int.parse(m[2]!), int.parse(m[1]!), m[4], m[5]);
  }
  return (null, null);
}

(String?, String?) _armarFecha(int anio, int mes, int dia, String? h, String? min) {
  if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return (null, null);
  final d = DateTime.utc(anio, mes, dia);
  if (d.month != mes) return (null, null); // 31/11 y parecidos
  String? hora;
  if (h != null && min != null) hora = _hhmm(int.parse(h), int.parse(min));
  return (fechaIso(d), hora == '00:00' ? null : hora);
}

String? _horaDe(DateTime d) => d.hour == 0 && d.minute == 0 ? null : _hhmm(d.hour, d.minute);

String? _hhmm(int h, int m) =>
    h < 0 || h > 23 || m < 0 || m > 59 ? null : '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

/// Hora de una celda: hora de Excel (fracción del día), fecha con hora o texto "8:00", "13.30", "2130".
String? leerHora(Object? v) {
  if (v is DateTime) return _hhmm(v.hour, v.minute);
  if (v is double) {
    final fraccion = v - v.floorToDouble();
    final minutos = (fraccion * 24 * 60).round();
    if (minutos == 24 * 60) return '00:00';
    return _hhmm(minutos ~/ 60, minutos % 60);
  }
  final s = _texto(v);
  var m = RegExp(r'^(\d{1,2})[:.hH](\d{2})').firstMatch(s);
  if (m != null) return _hhmm(int.parse(m[1]!), int.parse(m[2]!));
  m = RegExp(r'^(\d{1,2})(\d{2})$').firstMatch(s);
  if (m != null) return _hhmm(int.parse(m[1]!), int.parse(m[2]!));
  return null;
}

/// Número de una celda: 3250, "3250", "3.250" (miles), "3.250,5", "3,5".
double? leerNumero(Object? v) {
  if (v is double) return v;
  var s = _texto(v).replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}

/// Importe en dólares como lo guarda COMEX: "USD 2,48". Acepta 2.48, "USD 2,48", "U\$S 2.48", "\$2,48".
String? leerDinero(Object? v) {
  String usd(double n) => 'USD ${n.toStringAsFixed(2).replaceAll('.', ',')}';
  if (v is double) return usd(v);
  final s = _texto(v);
  if (s.isEmpty || RegExp(r'^#+$').hasMatch(s)) return null; // "######": columna angosta en Excel
  final limpio = s.replaceFirst(RegExp(r'^(USD|U\$S|US\$|\$)\s*', caseSensitive: false), '').trim();
  final n = RegExp(r'^[0-9.,]+$').hasMatch(limpio) ? leerNumero(limpio) : null;
  return n == null ? normalizarTarifa(limpio) : usd(n);
}

// ─────────────────────────────── Comparación ───────────────────────────────

enum TipoCambio { nuevo, actualiza, igual, error }

/// Lo que va a pasar con una fila de la planilla.
class CambioImport {
  CambioImport({
    required this.fila,
    required this.tipo,
    this.previo,
    this.error,
    this.cambios = const {},
    this.detalle = const [],
  });

  final FilaPlanilla fila;
  final TipoCambio tipo;
  final Vuelo? previo;
  final String? error;

  /// Columnas que se mandan a la nube (en un despacho existente, sólo las que cambian).
  final Map<String, Object?> cambios;

  /// Para mostrar: (dato, antes, después).
  final List<(String, String, String)> detalle;
}

/// Clave para emparejar: el AWB sin guiones ni espacios; sin AWB, vuelo + ETD + destino.
String _claveEmparejar(String awb, String vuelo, String etd, String destino) {
  final digitos = awb.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
  if (digitos.length >= 6) return 'AWB|$digitos';
  return 'SIN|${vuelo.replaceAll(' ', '').toUpperCase()}|$etd|${destino.toUpperCase()}';
}

/// Arma el plan: qué filas se crean, cuáles se actualizan y cuáles quedan igual.
List<CambioImport> compararConExistentes(PlanillaLeida planilla, List<Vuelo> existentes) {
  // Existentes agrupados por clave, en orden de ETD (así un AWB repetido se empareja fila a fila).
  final porClave = <String, List<Vuelo>>{};
  for (final v in existentes) {
    porClave.putIfAbsent(_claveEmparejar(v.awb, v.vuelo, v.etdFecha, v.destino), () => []).add(v);
  }
  for (final l in porClave.values) {
    l.sort((a, b) {
      final c = '${a.etdFecha} ${a.etdHora}'.compareTo('${b.etdFecha} ${b.etdHora}');
      return c != 0 ? c : a.registro.compareTo(b.registro);
    });
  }
  final usados = <String, int>{};

  final plan = <CambioImport>[];
  for (final f in planilla.filas) {
    final clave = _claveEmparejar(f.awb, txt(f.datos['vuelo']), txt(f.datos['fecha_etd1']), f.destino);
    final candidatos = porClave[clave] ?? const <Vuelo>[];
    final n = usados[clave] ?? 0;
    final previo = n < candidatos.length ? candidatos[n] : null;
    usados[clave] = n + 1;

    if (previo == null) {
      if (f.destino.isEmpty) {
        plan.add(CambioImport(fila: f, tipo: TipoCambio.error, error: 'Falta el destino'));
        continue;
      }
      plan.add(CambioImport(
        fila: f,
        tipo: TipoCambio.nuevo,
        cambios: {
          ...f.datos,
          if (f.etaFecha != null) 'fecha_eta_1': f.etaFecha,
          if (f.etaHora != null) 'hora_eta1': f.etaHora,
        },
      ));
      continue;
    }

    final nuevos = Map<String, Object?>.from(f.datos);
    // ETA de una planilla de un solo tramo: donde la tenía el despacho (tramo 2 si era con conexión).
    if (f.etaFecha != null || f.etaHora != null) {
      final tramo2 = previo.etaEnTramo2;
      if (f.etaFecha != null) nuevos[tramo2 ? 'fecha_eta_2' : 'fecha_eta_1'] = f.etaFecha;
      if (f.etaHora != null) nuevos[tramo2 ? 'hora_eta2' : 'hora_eta1'] = f.etaHora;
    }
    final cambios = <String, Object?>{};
    final detalle = <(String, String, String)>[];
    for (final e in nuevos.entries) {
      final antes = e.key == 'fecha_eta_2' ? (previo.f['fecha_eta_2'] ?? previo.f['fecha_eta 2']) : previo.f[e.key];
      if (_iguales(e.key, antes, e.value)) continue;
      cambios[e.key] = e.value;
      detalle.add((etiquetaColumnaVuelo(e.key), valorColumnaVuelo(e.key, antes), valorColumnaVuelo(e.key, e.value)));
    }
    plan.add(CambioImport(
      fila: f,
      tipo: cambios.isEmpty ? TipoCambio.igual : TipoCambio.actualiza,
      previo: previo,
      cambios: cambios,
      detalle: detalle,
    ));
  }
  return plan;
}

bool _iguales(String columna, Object? antes, Object? despues) {
  if (columna == 'pcs' || columna == 'kilos') return numDe(antes).round() == numDe(despues).round();
  var a = txt(antes);
  var b = txt(despues);
  if (columna.startsWith('fecha') || columna == 'ingreso') {
    a = a.length >= 10 ? a.substring(0, 10) : a;
    b = b.length >= 10 ? b.substring(0, 10) : b;
  } else if (columna.startsWith('hora')) {
    a = a.length >= 5 ? a.substring(0, 5) : a;
    b = b.length >= 5 ? b.substring(0, 5) : b;
  } else if (columna == 'awb') {
    // "176-69302763" y "176 69302763" son la misma guía.
    a = a.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    b = b.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  } else if (columna == 'tarifa_kg' || columna == 'fijos') {
    a = a.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
    b = b.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }
  return a.toUpperCase() == b.toUpperCase();
}

// ─────────────────────────────── Guardado ───────────────────────────────

/// Resultado de aplicar la importación.
class ResultadoImport {
  int creados = 0;
  int actualizados = 0;

  /// Guardados sólo en este equipo (sin conexión): se suben al sincronizar.
  int pendientes = 0;
  final errores = <String>[];
  final omitidas = <String>{};
}

/// Guarda en la nube los despachos nuevos y los cambios. [progreso] recibe (hechos, total).
Future<ResultadoImport> aplicarImportacion(
  Sesion s,
  List<CambioImport> plan, {
  void Function(int hechos, int total)? progreso,
}) async {
  final trabajo = plan.where((c) => c.tipo == TipoCambio.nuevo || c.tipo == TipoCambio.actualiza).toList();
  final r = ResultadoImport();
  var hechos = 0;
  for (final c in trabajo) {
    try {
      final fila = _filaParaGuardar(s, c);
      final omitidas = <String>[];
      final enNube = await DatosNube.guardar(
        tabla: RepoVuelos.tabla,
        clave: RepoVuelos.clave,
        alcance: RepoVuelos.alcance(s),
        fila: fila,
        copiaLocal: c.previo?.f,
        omitidas: omitidas,
      );
      r.omitidas.addAll(omitidas);
      if (!enNube) r.pendientes++;
      if (c.tipo == TipoCambio.nuevo) {
        r.creados++;
      } else {
        r.actualizados++;
      }
    } catch (e) {
      r.errores.add('Fila ${c.fila.numero}${c.fila.awb.isEmpty ? '' : ' (AWB ${c.fila.awb})'}: ${mensajeDe(e)}');
    }
    hechos++;
    progreso?.call(hechos, trabajo.length);
  }
  return r;
}

Map<String, Object?> _filaParaGuardar(Sesion s, CambioImport c) {
  final previo = c.previo;
  final fila = <String, Object?>{...c.cambios};
  if (previo == null) {
    fila['registro'] = RepoVuelos.nuevoRegistro();
    fila['temporada'] = Config.temporada;
    fila['usuario'] = s.nombre;
    fila['cliente'] ??= 'CECO';
    fila['status'] ??= 'PROGRAMADO';
  } else {
    fila['registro'] = previo.registro;
  }

  // Semana y fecha del despacho: por ETD; si no, por ingreso TCA; si no, la que ya tenía (o hoy).
  if (previo == null || fila.containsKey('fecha_etd1') || fila.containsKey('ingreso')) {
    final etd = txt(fila['fecha_etd1'] ?? previo?.etdFecha);
    final ingreso = txt(fila['ingreso'] ?? previo?.ingreso);
    final base = etd.isNotEmpty
        ? etd
        : (ingreso.isNotEmpty ? ingreso : (previo == null ? hoyIso() : RepoVuelos.txtFecha(previo.f['fecha'])));
    if (base.isNotEmpty) {
      fila['fecha'] = base;
      fila['semana'] = semanaDeDespacho(etd: base);
    }
  }
  return fila;
}
