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
/// [abreviatura] también sirve para buscar el stock (vista_pallet_stock_general puede traer cualquiera de las dos).
class OpcionMarca {
  const OpcionMarca(this.nombre, this.etiqueta, [this.abreviatura = '']);
  final String nombre;
  final String etiqueta;
  final String abreviatura;
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

  /// Plazas del día: una opción por AWB (el mismo vuelo puede tener varias, cada una con su capacidad).
  /// Una AWB cargada dos veces aparece una sola vez ('_awb_repetidas' = filas descartadas).
  List<Fila> plazasDelDia(String fecha) {
    final vistas = <String, Fila>{};
    final resultado = <Fila>[];
    for (final v in vuelosDelDia(fecha)) {
      final awb = txt(v['awb']);
      final clave = '${txt(v['vuelo']).toUpperCase()}|$awb';
      if (awb.isNotEmpty && vistas.containsKey(clave)) {
        final ya = vistas[clave]!;
        ya['_awb_repetidas'] = numDe(ya['_awb_repetidas']).toInt() + 1;
        continue;
      }
      final f = <String, Object?>{...v, '_awb_repetidas': 0};
      vistas[clave] = f;
      resultado.add(f);
    }
    String orden(Fila v) =>
        '${soloFecha(v['fecha_etd1'])} ${txt(v['hora_etd1']).padLeft(5, '0')} ${txt(v['vuelo'])} ${txt(v['awb'])}';
    return resultado..sort((a, b) => orden(a).compareTo(orden(b)));
  }

  /// Pallets ya guardados en otros programas para esa plaza (vuelo + AWB) y fecha.
  int palletsGuardadosEnPlaza(String vuelo, String fecha, String awb, {String? excluirPrograma}) {
    final f = soloFecha(fecha);
    var total = 0;
    for (final r in renglones) {
      if (txt(r['vuelo']) != vuelo || soloFecha(r['fecha']) != f || txt(r['awb']) != awb) continue;
      if (excluirPrograma != null && nroDe(r) == excluirPrograma) continue;
      total += numDe(r['cantidad']).toInt();
    }
    return total;
  }

  /// Vuelos del día con sus plazas juntas (ver [agruparPlazas]): uno por vuelo, fecha y forwarder.
  List<Fila> vuelosDelDiaAgrupados(String fecha) => agruparPlazas(vuelosDelDia(fecha));

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

  /// N° para un programa nuevo de la temporada (último + 1; incluye los cargados sin conexión).
  String get siguienteNro => '${siguienteNroPrograma(renglones.map((r) => r['programa_nro']))}';

  /// N° de pallet -> N° de programa donde ya figura (para avisar antes de volcarlo de nuevo).
  /// En edición se excluye el propio programa ([excluirPrograma]): sus pallets están en el formulario.
  Map<String, String> palletsProgramados({String? excluirPrograma}) {
    final resultado = <String, String>{};
    for (final r in renglones) {
      final nro = nroDe(r);
      if (excluirPrograma != null && nro == excluirPrograma) continue;
      for (final p in separarPallets(r['nro_pallet'])) {
        resultado.putIfAbsent(p, () => nro);
      }
    }
    return resultado;
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

/// En logistitcas_temporada cada fila es una PLAZA del vuelo (una AWB). El mismo vuelo del mismo día puede
/// tener varias: se juntan en una sola opción (vuelo + fecha ETD 1 + forwarder) con la capacidad (pcs) y los
/// kilos sumados. Una AWB repetida (la misma guía cargada dos veces) se cuenta una sola vez.
/// La fila resultante es la primera plaza con: pcs y kilos sumados, 'awb' = las AWB separadas por coma,
/// '_plazas' = cantidad de plazas y '_awb_repetidas' = filas descartadas por AWB repetida.
List<Fila> agruparPlazas(List<Fila> filas) {
  final grupos = <String, List<Fila>>{};
  for (final v in filas) {
    final dia = soloFecha(v['fecha_etd1']).isEmpty ? soloFecha(v['fecha']) : soloFecha(v['fecha_etd1']);
    final clave = [txt(v['vuelo']).toUpperCase(), dia, txt(v['forwarder']).toUpperCase()].join('|');
    grupos.putIfAbsent(clave, () => []).add(v);
  }
  final resultado = <Fila>[];
  for (final g in grupos.values) {
    final awbs = <String>[];
    var capacidad = 0, plazas = 0, repetidas = 0;
    var kilos = 0.0;
    for (final v in g) {
      final awb = txt(v['awb']);
      if (awb.isNotEmpty && awbs.contains(awb)) {
        repetidas++;
        continue;
      }
      if (awb.isNotEmpty) awbs.add(awb);
      plazas++;
      capacidad += numDe(v['pcs']).toInt();
      kilos += numDe(v['kilos']);
    }
    resultado.add({
      ...g.first,
      'pcs': capacidad,
      'kilos': kilos,
      'awb': awbs.join(', '),
      '_plazas': plazas,
      '_awb_repetidas': repetidas,
    });
  }
  // Por hora de salida (ETD 1) y vuelo.
  String orden(Fila v) => '${soloFecha(v['fecha_etd1'])} ${txt(v['hora_etd1']).padLeft(5, '0')} ${txt(v['vuelo'])}';
  return resultado..sort((a, b) => orden(a).compareTo(orden(b)));
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
    this.awb = '',
  });

  final int idTemp;
  final String camion;
  final String cliente;
  final String consignatario;
  final String marca;
  final String destino;
  String vuelo;

  /// Plaza del vuelo (AWB de logistitcas_temporada). Vacía en programas viejos.
  String awb;
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
      txt(r['hora_salida_vuelo']), txt(r['awb'])].join('|');
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
        awb: txt(r['awb']),
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

/// N° del programa nuevo: el mayor N° numérico + 1. Los viejos con letras ("PRG-2026-4821") no cuentan;
/// si todavía no hay ninguno numérico, arranca en 1.
int siguienteNroPrograma(Iterable<Object?> nros) {
  var mayor = 0;
  for (final n in nros) {
    final v = int.tryParse(txt(n));
    if (v != null && v > mayor) mayor = v;
  }
  return mayor + 1;
}

/// El N° de un programa nuevo tiene que ser un número entero positivo.
bool nroProgramaValido(String nro) => RegExp(r'^[1-9]\d{0,8}$').hasMatch(nro.trim());

/// "101, 102" -> ['101', '102'] (sin vacíos ni "-").
List<String> separarPallets(Object? v) =>
    [for (final s in txt(v).split(',')) if (s.trim().isNotEmpty && s.trim() != '-') s.trim()];

// ─────────────────────────── Stock de pallets ───────────────────────────

/// Códigos de calibre de cereza -> calibre de la grilla. Revisar contra lo que carga el empaque en el stock.
const codigosCalibre = {'XL': '24-26', 'J': '26-28', '2J': '28-30', '3J': '30-32', '4J': '32+', '5J': '32+'};

/// Calibre del stock ("26-28", "26/28", "26 - 28 mm", "J", "34") -> renglón de la grilla, o null si no se
/// puede deducir (en ese caso se elige a mano).
String? calibreDeGrilla(Object? valor) {
  final s = txt(valor).toUpperCase().replaceAll(RegExp(r'\s|MM'), '').replaceAll(RegExp(r'[/–_]'), '-');
  if (s.isEmpty) return null;
  if (calibresPrograma.contains(s)) return s;
  final porCodigo = codigosCalibre[s];
  if (porCodigo != null) return porCodigo;
  final nums = [for (final m in RegExp(r'\d+').allMatches(s)) int.parse(m[0]!)];
  if (nums.isEmpty) return null;
  if (nums.first >= 32) return '32+';
  if (nums.length >= 2) {
    final rango = '${nums[0]}-${nums[1]}';
    if (calibresPrograma.contains(rango)) return rango;
  }
  return null;
}

/// Un pallet de vista_pallet_stock_general. La vista trae una fila por pallet y calibre (o lote):
/// se agrupan por pallet_integrado.
class PalletStock {
  PalletStock({
    required this.pallet,
    required this.marca,
    required this.calibres,
    required this.detalle,
    required this.calibreGrilla,
    required this.cajas,
    required this.variedad,
    required this.categoria,
    required this.envase,
    required this.especie,
    required this.productor,
    required this.romaneo,
    required this.camara,
    required this.produccion,
  });

  final String pallet;
  final String marca;

  /// Calibre -> cajas, como figuran en el stock (más de uno = pallet mixto).
  final List<(String, int)> calibres;

  /// Cajas por calibre de la grilla ('' = fuera de la grilla) y color, para los resúmenes del stock.
  final List<({String calibre, String color, int cajas})> detalle;

  /// Renglón de la grilla al que se vuelca (el calibre con más cajas); null = hay que elegirlo.
  final String? calibreGrilla;
  final int cajas;
  final String variedad;
  final String categoria;
  final String envase;
  final String especie;
  final String productor;
  final String romaneo;
  final String camara;

  /// AAAA-MM-DD de la producción más vieja del pallet.
  final String produccion;

  bool get mixto => calibres.length > 1;

  /// Colores del pallet (en mayúsculas; "S/COLOR" si no tiene).
  late final Set<String> colores = {for (final d in detalle) d.color};
  String get color => colores.join(' / ');

  /// Calibres de la grilla que tiene el pallet ('' = alguno fuera de la grilla).
  late final Set<String> calibresGrilla = {for (final d in detalle) d.calibre};
  String get calibreOrigen => calibres.map((c) => c.$1).join(' / ');

  late final String busqueda = [pallet, marca, calibreOrigen, color, variedad, categoria, envase, productor, romaneo, camara]
      .join(' ')
      .toLowerCase();

  /// La marca del stock puede venir con el detalle o con la abreviatura de agronet_marcas.
  bool esDeMarca(String nombre, [String abreviatura = '']) {
    final m = marca.trim().toUpperCase();
    if (m.isEmpty) return false;
    return m == nombre.trim().toUpperCase() || (abreviatura.trim().isNotEmpty && m == abreviatura.trim().toUpperCase());
  }
}

/// Agrupa las filas del stock por pallet_integrado, ordenadas por calibre de la grilla y N° de pallet.
List<PalletStock> palletsDesdeStock(List<Fila> filas) {
  final grupos = <String, List<Fila>>{};
  for (final f in filas) {
    final p = txt(f['pallet_integrado']);
    if (p.isNotEmpty) grupos.putIfAbsent(p, () => []).add(f);
  }
  String unidos(List<Fila> g, String campo) =>
      {for (final f in g) if (txt(f[campo]).isNotEmpty) txt(f[campo])}.join(' / ');

  final lista = <PalletStock>[];
  for (final MapEntry(key: pallet, value: g) in grupos.entries) {
    final porCalibre = <String, int>{};
    for (final f in g) {
      final c = txt(f['calibre']).isEmpty ? 'S/C' : txt(f['calibre']);
      porCalibre[c] = (porCalibre[c] ?? 0) + numDe(f['cantidad']).toInt();
    }
    final calibres = [for (final e in porCalibre.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
    final porCalibreColor = <(String, String), int>{};
    for (final f in g) {
      final clave = (
        calibreDeGrilla(f['calibre']) ?? '',
        txt(f['color']).isEmpty ? 'S/COLOR' : txt(f['color']).toUpperCase(),
      );
      porCalibreColor[clave] = (porCalibreColor[clave] ?? 0) + numDe(f['cantidad']).toInt();
    }
    final fechas = [for (final f in g) if (soloFecha(f['fecha_produccion']).isNotEmpty) soloFecha(f['fecha_produccion'])]
      ..sort();
    lista.add(PalletStock(
      pallet: pallet,
      marca: unidos(g, 'marca'),
      calibres: calibres,
      detalle: [
        for (final MapEntry(key: (cal, col), value: cj) in porCalibreColor.entries) (calibre: cal, color: col, cajas: cj),
      ],
      calibreGrilla: calibreDeGrilla(calibres.first.$1),
      cajas: calibres.fold(0, (s, c) => s + c.$2),
      variedad: unidos(g, 'variedad'),
      categoria: unidos(g, 'categoria'),
      envase: unidos(g, 'envase'),
      especie: unidos(g, 'especie'),
      productor: unidos(g, 'productor'),
      romaneo: unidos(g, 'numero_romaneo_interno'),
      camara: unidos(g, 'codigo_camara'),
      produccion: fechas.isEmpty ? '' : fechas.first,
    ));
  }
  int orden(PalletStock p) {
    final i = p.calibreGrilla == null ? -1 : calibresPrograma.indexOf(p.calibreGrilla!);
    return i < 0 ? calibresPrograma.length : i;
  }

  return lista
    ..sort((a, b) {
      final c = orden(a).compareTo(orden(b));
      return c != 0 ? c : a.pallet.compareTo(b.pallet);
    });
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
        'awb': b.awb.isEmpty ? null : b.awb,
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
