import 'package:flutter/widgets.dart';

import '../../core/config.dart';
import '../../core/db/filas.dart';
import '../../core/exportar/exportar.dart';
import '../../core/formato.dart';
import 'programa_datos.dart';

/// PDF "PROGRAMA DE TRABAJO Y DESPACHO" (apaisado), con el mismo contenido que exportarProgramaAPDF
/// de la versión Electron: fichas del programa, un renglón por calibre, totales y firmas.
Future<bool> exportarProgramaPdf(BuildContext context, DatosPrograma d, ProgramaAgrupado p) {
  final renglones = p.renglones;
  final camiones = p.camiones;
  final vuelos = {for (final r in renglones) if (txt(r['vuelo']).isNotEmpty) txt(r['vuelo'])};

  return exportarPdf(
    context,
    nombreArchivo: 'Programa_Trabajo_${p.nro}',
    titulo: 'PROGRAMA DE TRABAJO Y DESPACHO',
    subtitulo: 'Empaque · Temporada ${Config.temporada}',
    apaisado: true,
    prefijoFolio: 'PRG',
    resumen: [
      ('Programa N°', p.nro),
      ('Fecha de empaque', formatearFecha(p.fecha)),
      ('Semana', '${semanaDeFecha(p.fecha) ?? '-'}'),
      ('Salida empaque', formatearFecha(p.salidaEmpaque, conHora: true)),
      ('Camiones', '${camiones.length}'),
      ('Pallets programados', fmtNum(p.pallets)),
      ('Vuelos', '${vuelos.length}'),
      ('Renglones', '${renglones.length}'),
    ],
    tablas: [
      TablaExport(
        titulo: 'Programa ${p.nro}',
        columnas: const [
          ColumnaExport('Camión'),
          ColumnaExport('Cliente'),
          ColumnaExport('Consignatario'),
          ColumnaExport('Marca'),
          ColumnaExport('Calibre'),
          ColumnaExport.total('Cant.', tipo: TipoDato.entero),
          ColumnaExport('Tamaño'),
          ColumnaExport('N° pallet(s)'),
          ColumnaExport('Destino'),
          ColumnaExport('Vuelo'),
          ColumnaExport('AWB'),
          ColumnaExport('Salida camión'),
          ColumnaExport('Salida vuelo'),
        ],
        filas: [
          for (final r in renglones)
            [
              txt(r['camion_no']).isEmpty ? 'S/D' : txt(r['camion_no']),
              txt(r['cliente']).isEmpty ? '-' : txt(r['cliente']),
              d.consignatarioDe(r),
              txt(r['marca']).isEmpty ? '-' : txt(r['marca']),
              txt(r['calibre']).isEmpty ? '-' : txt(r['calibre']),
              numDe(r['cantidad']).toInt(),
              txt(r['tamano']).isEmpty ? 'STD' : txt(r['tamano']),
              txt(r['nro_pallet']).isEmpty ? '-' : txt(r['nro_pallet']),
              txt(r['destino']).isEmpty ? '-' : txt(r['destino']),
              txt(r['vuelo']).isEmpty ? '-' : txt(r['vuelo']),
              txt(r['awb']).isEmpty ? '-' : txt(r['awb']),
              fechaHoraCorta(txt(r['salida_empaque']).isEmpty ? p.salidaEmpaque : r['salida_empaque']),
              fechaHoraCorta(r['hora_salida_vuelo']),
            ],
        ],
      ),
    ],
    firmas: const ['Responsable de empaque', 'Responsable COMEX', 'Transporte'],
  );
}
