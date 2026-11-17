import 'package:flutter/material.dart';

import '../../core/exportar/exportar.dart';
import '../../widgets/avisos.dart';
import 'modulo_page.dart' show BotonHero;

/// Lo que una pantalla quiere exportar: las tablas de lo que está a la vista (respetando filtros) y su contexto.
class InformePantalla {
  const InformePantalla({
    required this.titulo,
    required this.nombreArchivo,
    required this.tablas,
    this.subtitulo,
    this.resumen = const [],
    this.firmas = const [],
    this.apaisado,
    this.tablasPdf,
    this.graficos = const [],
    this.marcaAgua,
  });

  final String titulo;

  /// Sin extensión ni fecha, p. ej. 'COMEX_vuelos'.
  final String nombreArchivo;
  final List<TablaExport> tablas;

  /// Filtros aplicados / período, p. ej. 'Campaña 26_27 · Depósito CENTRAL'.
  final String? subtitulo;
  final List<(String, String)> resumen;
  final List<String> firmas;
  final bool? apaisado;

  /// Tablas del PDF cuando no son las mismas del Excel (p. ej. menos columnas para que entren en la hoja).
  /// null = las mismas [tablas].
  final List<TablaExport>? tablasPdf;

  /// Gráficos generales (con datos propios): PDF debajo del resumen; Excel en la hoja "Gráficos".
  /// Los gráficos de cada hoja van en [TablaExport.graficos].
  final List<GraficoExport> graficos;

  /// Marca de agua del PDF ("BORRADOR", "ANULADO"…).
  final String? marcaAgua;

  bool get vacio => tablas.every((t) => t.filas.isEmpty);
}

/// Botones "Excel" y "PDF" del encabezado de cada módulo (van en las acciones de `EncabezadoModulo`).
/// [armar] se llama al tocar: arma el informe con lo filtrado en ese momento (null = nada para exportar).
class BotonesExportar extends StatefulWidget {
  const BotonesExportar({super.key, required this.armar, this.armarPdf, this.prefijoFolio = 'SAL'});

  final Future<InformePantalla?> Function() armar;

  /// Informe propio para el PDF (p. ej. menos columnas que el Excel); null = el mismo de [armar].
  final Future<InformePantalla?> Function()? armarPdf;
  final String prefijoFolio;

  @override
  State<BotonesExportar> createState() => _BotonesExportarState();
}

class _BotonesExportarState extends State<BotonesExportar> {
  bool _ocupado = false;

  Future<void> _exportar(bool pdf) async {
    setState(() => _ocupado = true);
    try {
      final informe = await (pdf ? (widget.armarPdf ?? widget.armar) : widget.armar)();
      if (!mounted) return;
      if (informe == null || informe.vacio) {
        mostrarAviso(context, 'No hay datos para exportar con los filtros actuales.', tipo: TipoAviso.aviso);
        return;
      }
      if (pdf) {
        await exportarPdf(
          context,
          nombreArchivo: informe.nombreArchivo,
          titulo: informe.titulo,
          subtitulo: informe.subtitulo,
          tablas: informe.tablasPdf ?? informe.tablas,
          resumen: informe.resumen,
          firmas: informe.firmas,
          apaisado: informe.apaisado,
          graficos: informe.graficos,
          marcaAgua: informe.marcaAgua,
          prefijoFolio: widget.prefijoFolio,
        );
      } else {
        await exportarExcel(
          context,
          nombreArchivo: informe.nombreArchivo,
          titulo: informe.titulo,
          subtitulo: informe.subtitulo,
          hojas: informe.tablas,
          resumen: informe.resumen,
          indice: informe.tablas.length > 1,
          graficos: informe.graficos,
          prefijoFolio: widget.prefijoFolio,
        );
      }
    } catch (e) {
      if (mounted) mostrarAviso(context, 'No se pudo exportar: $e', tipo: TipoAviso.error);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        BotonHero(icono: Icons.table_view_rounded, texto: 'Excel', onTap: _ocupado ? null : () => _exportar(false)),
        BotonHero(icono: Icons.picture_as_pdf_rounded, texto: 'PDF', onTap: _ocupado ? null : () => _exportar(true)),
      ],
    );
  }
}
