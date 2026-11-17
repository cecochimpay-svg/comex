import '../../core/config.dart';
import '../../core/exportar/exportar.dart';
import '../../core/formato.dart';
import '../modulo/botones_exportar.dart';
import 'vuelos_datos.dart';

/// Excel / PDF con las mismas columnas y el mismo orden que la planilla de logística (TCI),
/// agrupado por semana ("WEEK 46 / 2026") como la planilla.
InformePantalla informeVuelos(List<Vuelo> lista, FiltrosVuelos f, {required bool todosLosOperadores, String? operador}) {
  final ordenados = [...lista]..sort((a, b) => b.semana.compareTo(a.semana));
  String fechaHora(String fecha, String hora) => fecha.isEmpty ? '' : '$fecha${hora.isEmpty ? '' : ' $hora'}';

  final columnas = <ColumnaExport>[
    const ColumnaExport('Week'),
    const ColumnaExport('AWB'),
    const ColumnaExport('Ingreso TCA requerido', tipo: TipoDato.fecha),
    const ColumnaExport('Destino'),
    const ColumnaExport('Ruta'),
    const ColumnaExport('Vuelo'),
    const ColumnaExport('Proforma'),
    const ColumnaExport('ETD'),
    const ColumnaExport('Conex'),
    const ColumnaExport('ETA'),
    const ColumnaExport('Tarimas', tipo: TipoDato.entero, sumar: true),
    const ColumnaExport('Peso (kg)', tipo: TipoDato.entero, sumar: true),
    const ColumnaExport('Tarifa'),
    const ColumnaExport('Status'),
    const ColumnaExport('CNNE'),
    if (todosLosOperadores) const ColumnaExport('Operador'),
  ];

  final filas = [
    for (final v in ordenados)
      [
        'WEEK ${v.semana} / ${Config.temporada}',
        v.awb,
        v.ingreso,
        v.destino,
        v.ruta,
        v.vuelo,
        v.proforma,
        fechaHora(v.etdFecha, v.etdHora),
        v.conex.isEmpty ? 'DIRECTO' : v.conex,
        fechaHora(v.etaFecha, v.etaHora),
        v.tarimas,
        v.peso,
        v.tarifa,
        v.status,
        v.cnne,
        if (todosLosOperadores) v.usuario,
      ],
  ];

  final tarimas = lista.fold<int>(0, (a, v) => a + v.tarimas);
  final peso = lista.fold<double>(0, (a, v) => a + v.peso);
  final destinos = lista.map((v) => v.destino).where((d) => d.isNotEmpty).toSet().length;
  final semanaTxt = f.semana == null ? 'Todas las semanas' : 'Week ${f.semana} / ${Config.temporada}';

  return InformePantalla(
    titulo: 'Programación de despachos',
    nombreArchivo: f.semana == null ? 'COMEX_despachos' : 'COMEX_despachos_week_${f.semana}',
    subtitulo: [
      semanaTxt,
      if (f.status != null) 'Status ${f.status}',
      if (f.texto.trim().isNotEmpty) 'Búsqueda "${f.texto.trim()}"',
      todosLosOperadores ? 'Todos los operadores' : 'Operador ${operador ?? ''}',
    ].join(' · '),
    apaisado: true,
    resumen: [
      ('Despachos', fmtNum(lista.length)),
      ('Tarimas', fmtNum(tarimas)),
      ('Peso', '${fmtNum(peso)} kg'),
      ('Destinos', fmtNum(destinos)),
    ],
    tablas: [
      TablaExport(
        titulo: 'Despachos',
        columnas: columnas,
        filas: filas,
        agruparPor: 0,
        columnaEstado: null,
      ),
    ],
  );
}
