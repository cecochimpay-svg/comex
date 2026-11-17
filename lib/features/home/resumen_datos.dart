import '../../core/formato.dart';

/// Números vivos del menú de COMEX (tarjetas del inicio, panel de cada área, menús desplegables).
class ResumenAreas {
  const ResumenAreas({
    required this.semanaActual,
    required this.despachosSemana,
    required this.tarimasSemana,
    required this.kilosSemana,
    required this.despachosTemporada,
    required this.destinosSemana,
    required this.programasSemana,
    required this.programasTemporada,
    required this.pendientes,
  });

  final int semanaActual;
  final int despachosSemana;
  final int tarimasSemana;
  final double kilosSemana;
  final int despachosTemporada;
  final int destinosSemana;
  final int programasSemana;
  final int programasTemporada;

  /// Cambios sin subir por área (clave de categoría -> cantidad).
  final Map<String, int> pendientes;

  int pendientesDe(String clave) => pendientes[clave] ?? 0;
}

/// Número grande de una tarjeta con su leyenda ("12" / "despachos en la semana 46").
class DatoVivo {
  const DatoVivo(this.valor, this.leyenda);

  final String valor;
  final String leyenda;

  @override
  String toString() => leyenda.isEmpty ? valor : '$valor $leyenda';
}

String _plural(int n, String uno, String varios) => '${fmtNum(n)} ${n == 1 ? uno : varios}';

/// Kilos en toneladas a partir de una tonelada ("12,4 t", "850 kg").
String fmtToneladas(num kg) => kg.abs() >= 1000 ? '${fmtNum(kg / 1000, decimales: 1)} t' : '${fmtNum(kg)} kg';

/// Dato principal de la tarjeta de un área.
DatoVivo datoPrincipal(String clave, ResumenAreas r) => switch (clave) {
  'DESPACHOS' => DatoVivo(
    fmtNum(r.despachosSemana),
    '${r.despachosSemana == 1 ? 'despacho' : 'despachos'} en la semana ${r.semanaActual}',
  ),
  'PROGRAMA' => DatoVivo(
    fmtNum(r.programasSemana),
    '${r.programasSemana == 1 ? 'programa' : 'programas'} en la semana ${r.semanaActual}',
  ),
  _ => const DatoVivo('—', ''),
};

/// Datos chicos que acompañan al principal.
List<DatoVivo> datosSecundarios(String clave, ResumenAreas r) => switch (clave) {
  'DESPACHOS' => [
    DatoVivo(fmtNum(r.tarimasSemana), r.tarimasSemana == 1 ? 'tarima' : 'tarimas'),
    DatoVivo(fmtToneladas(r.kilosSemana), 'de peso'),
    DatoVivo(fmtNum(r.destinosSemana), r.destinosSemana == 1 ? 'destino' : 'destinos'),
  ],
  'PROGRAMA' => [DatoVivo(fmtNum(r.programasTemporada), 'en la temporada')],
  _ => const [],
};

/// Dato vivo corto de una pantalla (tarjetas del panel, desplegables y hoja "Más"). null = no tiene.
String? datoDePantalla(String ref, ResumenAreas r) => switch (ref) {
  'VUELOS' => '${_plural(r.despachosSemana, 'despacho', 'despachos')} esta semana · ${fmtNum(r.despachosTemporada)} en la temporada',
  'PROGRAMA' => '${_plural(r.programasSemana, 'programa', 'programas')} esta semana',
  _ => null,
};

/// Área a la que pertenece una fila sin subir de [tabla].
String? areaDeTabla(String tabla) => switch (tabla) {
  'logistitcas_temporada' => 'DESPACHOS',
  'comex_programa_trabajo' || 'comex_proyeccion_dias' => 'PROGRAMA',
  _ => null,
};

/// Semana ISO de una fecha (la misma cuenta que la planilla de logística: "WEEK 46 / 2026").
int semanaIso(DateTime fecha) {
  final d = DateTime.utc(fecha.year, fecha.month, fecha.day);
  final jueves = d.add(Duration(days: 4 - (d.weekday)));
  final inicio = DateTime.utc(jueves.year, 1, 1);
  return (jueves.difference(inicio).inDays ~/ 7) + 1;
}
