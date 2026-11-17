import '../../core/config.dart';
import '../../core/db/filas.dart';
import '../home/resumen_datos.dart' show semanaIso;

/// Datos y reglas puras del Programa de trabajo (programa/programa_trab.html de la versión Electron).
/// Sin Flutter: se prueban solas.

/// Calibres de la grilla del programa (mismo orden que la versión Electron).
const calibresPrograma = ['24-26', '26-28', '28-30', '30-32', '32+'];

/// Conceptos de la proyección de 11 días: (campo en comex_proyeccion_dias sin "_kg", rótulo).
const conceptosProyeccion = [
  ('cosecha', 'Cosecha'),
  ('inspeccion', 'Inspección'),
  ('carga', 'Carga'),
  ('ezeiza', 'Ezeiza'),
];

const maxBloquesPrograma = 8;
const maxCamiones = 8;

/// Marcas de contingencia si no se pudo leer agronet_marcas (las mismas de la versión Electron).
const marcasReserva = ['CHIMPAY', 'FINCA CHIMPAY', 'DELEITE', 'DELEITE BAJO', 'NATIVA', 'CERESOL', 'MOÑO AZUL'];

/// Consignatario de un cliente (de clientes_consignatarios), con su destino habitual.
class OpcionConsignatario {
  const OpcionConsignatario(this.consignatario, this.destino);
  final String consignatario;
  final String destino;

  String get etiqueta => destino.isEmpty ? consignatario : '$consignatario · $destino';
}

/// Marca de agronet_marcas: se guarda el nombre (detalle) y se muestra con la abreviatura.
class OpcionMarca {
  const OpcionMarca(this.nombre, this.etiqueta);
  final String nombre;
  final String etiqueta;
}

/// Todo lo que usa la pantalla, leído de la nube (o de la copia local sin conexión).
class DatosPrograma {
  DatosPrograma({
    required this.vuelos,
    required this.proyecciones,
    required this.renglones,
    required this.clientes,
    required this.marcas,
    required this.offline,
  });

  /// logistitcas_temporada de la temporada (para el cruce por día y el vuelo de cada bloque).
  final List<Fila> vuelos;

  /// comex_proyeccion_dias por fecha (las del usuario y las que no tienen usuario).
  final Map<String, Fila> proyecciones;

  /// comex_programa_trabajo de la temporada: un renglón por calibre, ordenados por fecha descendente.
  final List<Fila> renglones;

  /// Cliente -> consignatarios activos (clientes ordenados).
  final Map<String, List<OpcionConsignatario>> clientes;
  final List<OpcionMarca> marcas;
  final bool offline;

  List<String> get nombresClientes => clientes.keys.toList()..sort();

  /// Renglones de un programa (los viejos sin número se agrupan por fecha, como en Electron).
  List<Fila> renglonesDe(String nro) => [for (final r in renglones) if (nroDe(r) == nro) r];

  /// La tabla no siempre guardó el consignatario: se deduce por cliente + destino.
  String deducirConsignatario(Object? cliente, Object? destino) {
    final lista = clientes[txt(cliente)] ?? const <OpcionConsignatario>[];
    for (final o in lista) {
      if (o.destino == txt(destino)) return o.consignatario;
    }
    return '-';
  }

  String consignatarioDe(Fila r) {
    final c = txt(r['consignatario']);
    return c.isNotEmpty && c != '-' ? c : deducirConsignatario(r['cliente'], r['destino']);
  }

  /// Vuelos que salen el [fecha]: coincide la fecha del despacho o la ETD 1 (filtro estricto de Electron).
  List<Fila> vuelosDelDia(String fecha) {
    final f = soloFecha(fecha);
    if (f.isEmpty) return const [];
    return [
      for (final v in vuelos)
        if (soloFecha(v['fecha']) == f || soloFecha(v['fecha_etd1']) == f) v,
    ];
  }

  /// Pallets ya guardados en otros programas para ese vuelo y fecha. En edición se excluye el propio
  /// programa ([excluirPrograma]), porque sus bloques están en el formulario.
  int palletsGuardadosEnVuelo(String vuelo, String fecha, {String? excluirPrograma}) {
    final f = soloFecha(fecha);
    var total = 0;
    for (final r in renglones) {
      if (txt(r['vuelo']) != vuelo || soloFecha(r['fecha']) != f) continue;
      if (excluirPrograma != null && nroDe(r) == excluirPrograma) continue;
      total += numDe(r['cantidad']).toInt();
    }
    return total;
  }

  /// Programas agrupados (un renglón por programa con el total de pallets), en el orden de [renglones].
  List<ProgramaAgrupado> get programas {
    final grupos = <String, ProgramaAgrupado>{};
    for (final r in renglones) {
      final nro = nroDe(r);
      final g = grupos.putIfAbsent(nro, () => ProgramaAgrupado(nro, r));
      g.renglones.add(r);
      g.pallets += numDe(r['cantidad']).toInt();
    }
    return grupos.values.toList();
  }

  bool nroEnUso(String nro, {String? salvo}) =>
      renglones.any((r) => txt(r['programa_nro']) == nro && !(salvo != null && txt(r['programa_nro']) == salvo));
}

/// Un programa en la grilla: los datos del primer renglón y el total de pallets.
class ProgramaAgrupado {
  ProgramaAgrupado(this.nro, this.primero);

  final String nro;
  final Fila primero;
  final renglones = <Fila>[];
  int pallets = 0;

  String get fecha => soloFecha(primero['fecha']);
  String get camion => txt(primero['camion_no']).isEmpty ? 'S/D' : txt(primero['camion_no']);
  String get cliente => txt(primero['cliente']);
  String get consignatario => txt(primero['consignatario']).isEmpty ? '-' : txt(primero['consignatario']);
  String get marca => txt(primero['marca']);
  String get destino => txt(primero['destino']);
  String get vuelo => txt(primero['vuelo']);
  String get salidaEmpaque => txt(primero['salida_empaque']);
  Set<String> get camiones => {for (final r in renglones) txt(r['camion_no']).isEmpty ? 'S/D' : txt(r['camion_no'])};
  bool get pendiente => renglones.any((r) => '${r['_sincronizado']}' == '0');
}

String nroDe(Fila r) => txt(r['programa_nro']).isEmpty ? 'PRG-${txt(r['fecha'])}' : txt(r['programa_nro']);

// ─────────────────────────── Bloques del formulario ───────────────────────────

/// Un calibre de un bloque. [id] = renglón ya guardado en Supabase (en edición se actualiza, no se duplica).
class CalibreBloque {
  CalibreBloque({required this.calibre, required this.cantidad, this.tamano = 'STD', this.nroPallet, this.id});

  final String calibre;
  final int cantidad;
  final String tamano;
  final String? nroPallet;
  final int? id;
}

/// Bloque del programa: un camión + cliente + consignatario + marca + vuelo con sus calibres.
class Bloque {
  Bloque({
    required this.idTemp,
    required this.camion,
    required this.cliente,
    required this.consignatario,
    required this.marca,
    required this.destino,
    required this.vuelo,
    required this.horaSalidaVuelo,
    required this.calibres,
  });

  final int idTemp;
  final String camion;
  final String cliente;
  final String consignatario;
  final String marca;
  final String destino;
  String vuelo;
  String horaSalidaVuelo;
  final List<CalibreBloque> calibres;

  int get total => calibres.fold(0, (a, c) => a + c.cantidad);
  String get resumenCalibres => calibres.map((c) => '${c.calibre}: ${c.cantidad}').join(' · ');
}

int _contadorTemp = 0;
int nuevoIdTemp() => ++_contadorTemp;

/// Reconstruye los bloques a partir de los renglones guardados (uno por calibre).
/// [conservarIds]: en edición los calibres recuerdan su id para actualizarse; en una copia, no.
List<Bloque> bloquesDesdeRenglones(DatosPrograma d, List<Fila> renglones, {required bool conservarIds}) {
  final grupos = <String, Bloque>{};
  for (final r in renglones) {
    final consignatario = d.consignatarioDe(r);
    final camion = txt(r['camion_no']).isEmpty ? 'S/D' : txt(r['camion_no']);
    final clave = [camion, txt(r['cliente']), consignatario, txt(r['marca']), txt(r['destino']), txt(r['vuelo']),
      txt(r['hora_salida_vuelo'])].join('|');
    final b = grupos.putIfAbsent(
      clave,
      () => Bloque(
        idTemp: nuevoIdTemp(),
        camion: camion,
        cliente: txt(r['cliente']),
        consignatario: consignatario,
        marca: txt(r['marca']),
        destino: txt(r['destino']),
        vuelo: txt(r['vuelo']).isEmpty ? '-' : txt(r['vuelo']),
        horaSalidaVuelo: txt(r['hora_salida_vuelo']),
        calibres: [],
      ),
    );
    final id = int.tryParse(txt(r['id']));
    b.calibres.add(CalibreBloque(
      calibre: txt(r['calibre']),
      cantidad: numDe(r['cantidad']).toInt(),
      tamano: txt(r['tamano']).isEmpty ? 'STD' : txt(r['tamano']),
      nroPallet: txt(r['nro_pallet']).isEmpty ? null : txt(r['nro_pallet']),
      id: conservarIds ? id : null,
    ));
  }
  return grupos.values.toList();
}

/// "101, 102" o "200-205" -> ['101', '102'] / ['200', …, '205'] (lo que no es rango queda tal cual).
List<String> parsearRangoPallets(String texto) {
  final resultado = <String>[];
  for (final parte in texto.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
    if (parte.contains('-')) {
      final lados = parte.split('-').map((s) => s.trim()).toList();
      final inicio = lados.length == 2 ? int.tryParse(lados[0]) : null;
      final fin = lados.length == 2 ? int.tryParse(lados[1]) : null;
      if (inicio != null && fin != null && inicio <= fin) {
        for (var i = inicio; i <= fin; i++) {
          resultado.add('$i');
        }
        continue;
      }
    }
    resultado.add(parte);
  }
  return resultado;
}

String nombreCamion(int n) => 'CAMIÓN ${n.toString().padLeft(2, '0')}';

/// Siguiente camión de la lista ("CAMIÓN 03" si ya están el 01 y el 02).
String siguienteCamion(List<String> lista) {
  final numeros = [for (final n in lista) ?int.tryParse(n.replaceAll(RegExp(r'\D'), ''))];
  return nombreCamion((numeros.isEmpty ? 0 : numeros.reduce((a, b) => a > b ? a : b)) + 1);
}

String generarNroPrograma() {
  final ms = '${DateTime.now().millisecondsSinceEpoch}';
  return 'PRG-${Config.temporada}-${ms.substring(ms.length - 4)}';
}

// ─────────────────────────── Renglones a guardar ───────────────────────────

/// Renglones de comex_programa_trabajo (uno por calibre de cada bloque), igual que la versión Electron.
List<Map<String, Object?>> renglonesAGuardar({
  required List<Bloque> bloques,
  required String nro,
  required String fecha,
  required String? salidaEmpaque,
  required String usuario,
  required bool edicion,
}) => [
  for (final b in bloques)
    for (final c in b.calibres)
      {
        'temporada': Config.temporada,
        'semana': semanaDeFecha(fecha) ?? 1,
        'programa_nro': nro,
        'fecha': fecha,
        'cliente': b.cliente,
        'consignatario': b.consignatario.isNotEmpty && b.consignatario != '-' ? b.consignatario : null,
        'marca': b.marca,
        'calibre': c.calibre,
        'cantidad': c.cantidad,
        'tamano': c.tamano.isEmpty ? 'STD' : c.tamano,
        'nro_pallet': c.nroPallet,
        'destino': b.destino.isEmpty ? null : b.destino,
        'vuelo': b.vuelo.isEmpty ? null : b.vuelo,
        'hora_salida_vuelo': b.horaSalidaVuelo.isEmpty ? null : b.horaSalidaVuelo,
        'salida_empaque': salidaEmpaque,
        'camion_no': b.camion.isEmpty ? 'S/D' : b.camion,
        'usuario': usuario,
        if (edicion && c.id != null) 'id': c.id,
      },
];

// ─────────────────────────── Fechas ───────────────────────────

/// "2026-11-12T08:00:00" / "2026-11-12 08:00" -> "2026-11-12".
String soloFecha(Object? v) {
  final s = txt(v);
  return s.length >= 10 ? s.substring(0, 10) : s;
}

DateTime? fechaDe(Object? v) {
  final s = soloFecha(v);
  final p = s.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  return y == null || m == null || d == null ? null : DateTime(y, m, d);
}

String isoDe(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int? semanaDeFecha(Object? v) {
  final d = fechaDe(v);
  return d == null ? null : semanaIso(d);
}

/// 11 días desde [desde] (AAAA-MM-DD).
List<String> fechas11Dias(String desde) {
  final base = fechaDe(desde) ?? DateTime.now();
  return [for (var i = 0; i < 11; i++) isoDe(DateTime(base.year, base.month, base.day + i))];
}

const _diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

String diaSemana(String iso) {
  final d = fechaDe(iso);
  return d == null ? '' : _diasSemana[d.weekday - 1];
}

/// "12/11" de "2026-11-12".
String diaMes(String iso) {
  final p = soloFecha(iso).split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}' : iso;
}

/// Igual que PDF_COMEX.formatearFecha: "12/11/2026" (con [conHora], "12/11/2026 08:00").
String formatearFecha(Object? valor, {bool conHora = false}) {
  final s = txt(valor).replaceFirst(' ', 'T');
  if (s.isEmpty) return '-';
  final partes = s.split('T');
  final f = partes[0].split('-');
  if (f.length != 3 || f.any((x) => x.isEmpty)) return txt(valor);
  final fecha = '${f[2].length > 2 ? f[2].substring(0, 2) : f[2]}/${f[1]}/${f[0]}';
  if (!conHora || partes.length < 2 || partes[1].isEmpty) return fecha;
  final h = partes[1];
  return '$fecha ${h.length > 5 ? h.substring(0, 5) : h}';
}

/// Igual que PDF_COMEX.fechaHoraCorta: "12/11 08:00".
String fechaHoraCorta(Object? valor) {
  if (txt(valor).isEmpty) return '-';
  final completa = formatearFecha(valor, conHora: true);
  if (completa.length > 10) return completa.substring(0, 5) + completa.substring(10);
  return completa.length > 5 ? completa.substring(0, 5) : completa;
}

/// "2026-11-12T08:00" para mostrar: "2026-11-12 08:00".
String salidaLegible(Object? v) => txt(v).isEmpty ? '-' : txt(v).replaceFirst('T', ' ');

/// Valor de un datetime-local ("AAAA-MM-DDTHH:MM") a partir de lo guardado.
String aFechaHoraLocal(Object? v) {
  final s = txt(v).replaceFirst(' ', 'T');
  return s.length > 16 ? s.substring(0, 16) : s;
}
