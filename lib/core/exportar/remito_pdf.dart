import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'modelo.dart';
import 'pdf_comun.dart';

/// Tarjeta del remito (origen, destino, transporte…): título, dato principal y renglones.
class TarjetaRemito {
  const TarjetaRemito(this.titulo, this.principal, [this.renglones = const []]);

  final String titulo;
  final String principal;
  final List<String> renglones;
}

/// Datos de un remito (comprobante de un egreso). Lo arma cada pantalla a partir de su fila.
class RemitoExport {
  const RemitoExport({
    required this.titulo,
    required this.numero,
    required this.folio,
    required this.emitido,
    required this.operario,
    required this.columnas,
    required this.renglones,
    this.subtitulo,
    this.condicion,
    this.condicionAlerta = false,
    this.datos = const [],
    this.tarjetas = const [],
    this.totalRenglones,
    this.observaciones = const [],
    this.valorizacion = const [],
    this.total,
    this.firmas = const [],
    this.copias = const ['ORIGINAL', 'DUPLICADO'],
  });

  /// "REMITO INTERNO DE DESPACHO", "REMITO DE SALIDA"…
  final String titulo;
  final String? subtitulo;
  final String numero;
  final String folio;
  final DateTime emitido;
  final String operario;

  /// Pastilla junto al número ("DECLARADO", "NO DECLARADO"); [condicionAlerta] la pinta de naranja.
  final String? condicion;
  final bool condicionAlerta;

  /// Cajitas grises de una línea (Fecha, Sale de, Destino…). Van de a cinco por renglón.
  final List<(String, String)> datos;
  final List<TarjetaRemito> tarjetas;
  final List<ColumnaExport> columnas;
  final List<List<Object?>> renglones;

  /// Texto a la derecha debajo de la tabla ("TOTAL: 1 ítem · 25 L").
  final String? totalRenglones;
  final List<String> observaciones;

  /// Valorización de referencia (concepto, valor) y el total destacado.
  final List<(String, String)> valorizacion;
  final (String, String)? total;

  /// Firmas: (rol, aclaración).
  final List<(String, String?)> firmas;

  /// Una copia por etiqueta, una debajo de la otra en A4 con línea de corte.
  final List<String> copias;
}

/// Remito en A4 con el estilo de oficina: ORIGINAL arriba y DUPLICADO abajo, separados por "cortar aquí".
Future<Uint8List> generarRemitoPdf(RemitoExport r, {RecursosPdf recursos = const RecursosPdf()}) async {
  final b = BasePdf(recursos);
  final pdf = pw.Document(
    theme: b.tema,
    title: '${r.titulo} Nº ${r.numero}',
    author: r.operario,
    creator: MarcaExport.pie,
  );
  final copias = r.copias.isEmpty ? const [''] : r.copias;
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 22, marginRight: 22, marginTop: 20, marginBottom: 18),
      theme: b.tema,
      build: (_) => [
        for (var i = 0; i < copias.length; i++) ...[if (i > 0) _corte(b), _copia(b, r, copias[i])],
      ],
    ),
  );
  return pdf.save();
}

pw.Widget _corte(BasePdf b) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 8),
  child: pw.Row(
    children: [
      pw.Expanded(
        child: pw.Divider(color: ColoresPdf.linea, borderStyle: pw.BorderStyle.dashed),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6),
        child: b.texto('cortar aquí', tam: 6, color: ColoresPdf.gris),
      ),
      pw.Expanded(
        child: pw.Divider(color: ColoresPdf.linea, borderStyle: pw.BorderStyle.dashed),
      ),
    ],
  ),
);

pw.Widget _copia(BasePdf b, RemitoExport r, String etiqueta) {
  pw.Widget dato(String t, String v) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 2),
      padding: const pw.EdgeInsets.fromLTRB(7, 4, 7, 5),
      decoration: pw.BoxDecoration(color: ColoresPdf.grisClaro, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          b.texto(t.toUpperCase(), tam: 6.2, color: ColoresPdf.gris),
          pw.SizedBox(height: 1),
          b.texto(v.trim().isEmpty ? '-' : v, tam: 8.6, negrita: true, lineas: 2),
        ],
      ),
    ),
  );

  final filasDatos = [
    for (var i = 0; i < r.datos.length; i += 5) r.datos.sublist(i, i + 5 > r.datos.length ? r.datos.length : i + 5),
  ];
  final colorCondicion = r.condicionAlerta ? ColoresPdf.naranja : ColoresPdf.verdeOscuro;

  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: ColoresPdf.verde, width: 1.2),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Membrete.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            b.logoEmpresa(42),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  b.texto(MarcaExport.empresa, tam: 8.5, negrita: true, color: ColoresPdf.gris),
                  b.texto(MarcaExport.sub, tam: 7, color: ColoresPdf.gris),
                  pw.SizedBox(height: 3),
                  b.texto(r.titulo, tam: 14, negrita: true, color: ColoresPdf.verdeOscuro),
                  if (r.subtitulo != null) b.texto(r.subtitulo!, tam: 7.4, color: ColoresPdf.gris),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    if (r.condicion != null && r.condicion!.isNotEmpty) ...[
                      b.pastilla(r.condicion!, color: colorCondicion, tam: 6.6),
                      pw.SizedBox(width: 4),
                    ],
                    if (etiqueta.isNotEmpty)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: ColoresPdf.verde,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: b.texto(etiqueta, tam: 7, color: PdfColors.white, negrita: true),
                      ),
                  ],
                ),
                pw.SizedBox(height: 3),
                b.texto('Nº ${r.numero}', tam: 14, negrita: true, color: ColoresPdf.verde),
                b.codigoBarras(r.folio, ancho: 120, alto: 18),
              ],
            ),
          ],
        ),
        if (filasDatos.isNotEmpty) pw.SizedBox(height: 6),
        for (final fila in filasDatos)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [for (final (t, v) in fila) dato(t, v)],
            ),
          ),
        if (r.tarjetas.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < r.tarjetas.length; i++) ...[
                if (i > 0) pw.SizedBox(width: 6),
                pw.Expanded(child: b.tarjeta(r.tarjetas[i].titulo, r.tarjetas[i].principal, r.tarjetas[i].renglones)),
              ],
            ],
          ),
        ],
        pw.SizedBox(height: 6),
        b.tabla(r.columnas, r.renglones, numerar: true, tam: 7.6),
        pw.SizedBox(height: 4),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (final o in r.observaciones.where((o) => o.trim().isNotEmpty))
                    b.texto(o, tam: 7.4, color: ColoresPdf.gris, lineas: 3),
                ],
              ),
            ),
            if (r.totalRenglones != null)
              b.texto(r.totalRenglones!, tam: 8.5, negrita: true, color: ColoresPdf.verdeOscuro),
          ],
        ),
        if (r.valorizacion.isNotEmpty || r.total != null) ...[
          pw.SizedBox(height: 5),
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(9, 5, 9, 6),
            decoration: pw.BoxDecoration(
              color: ColoresPdf.verdeClaro,
              border: pw.Border.all(color: ColoresPdf.linea, width: 0.6),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      b.texto('VALORIZACIÓN DE REFERENCIA', tam: 6.6, color: ColoresPdf.verde, negrita: true),
                      pw.SizedBox(height: 2),
                      pw.Wrap(
                        spacing: 14,
                        runSpacing: 2,
                        children: [
                          for (final (k, v) in r.valorizacion)
                            pw.RichText(
                              text: pw.TextSpan(
                                style: const pw.TextStyle(fontSize: 7.6, color: ColoresPdf.tinta),
                                children: [
                                  pw.TextSpan(
                                    text: b.t('$k: '),
                                    style: const pw.TextStyle(color: ColoresPdf.gris),
                                  ),
                                  pw.TextSpan(
                                    text: b.t(v),
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (r.total != null)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      b.texto(r.total!.$1.toUpperCase(), tam: 6.4, color: ColoresPdf.gris, negrita: true),
                      b.texto(r.total!.$2, tam: 12, color: ColoresPdf.verde, negrita: true),
                    ],
                  ),
              ],
            ),
          ),
        ],
        if (r.firmas.isNotEmpty) pw.Row(children: [for (final (rol, nombre) in r.firmas) b.firma(rol, nombre: nombre)]),
        pw.SizedBox(height: 5),
        pw.Row(
          children: [
            if (b.logoSistema != null) ...[
              pw.SizedBox(width: 10, height: 10, child: pw.Image(b.logoSistema!)),
              pw.SizedBox(width: 4),
            ],
            pw.Expanded(child: b.texto(pieInstitucionalPdf, tam: 6, color: ColoresPdf.gris)),
            b.texto(
              'Emitido ${fechaHoraExport(r.emitido)} por ${r.operario}  ·  ${r.folio}',
              tam: 6,
              color: ColoresPdf.gris,
            ),
          ],
        ),
      ],
    ),
  );
}
