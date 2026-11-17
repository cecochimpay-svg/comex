import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'grafico_pdf.dart';
import 'modelo.dart';
import 'pdf_comun.dart';

export 'pdf_comun.dart' show RecursosPdf;

/// Arma el PDF con el formato de oficina: membrete con logo, título, folio con código de barras, emisión y
/// operario en cada hoja; tarjetas de indicadores (el resumen); gráficos vectoriales; tablas con encabezado verde
/// repetido, filas alternadas, grupos con subtotal (sin encabezados huérfanos) y totales; firmas opcionales y
/// pie institucional con "Hoja n de m".
/// Con [DocumentoExport.portada] agrega una primera página de presentación (informe ejecutivo); con varias
/// secciones, una hoja de contenido con el número de hoja de cada una (y marcadores del PDF).
/// [TablaExport.hojaNueva] en false hace que la sección siga debajo de la anterior.
Future<Uint8List> generarPdf(DocumentoExport doc, {RecursosPdf recursos = const RecursosPdf()}) async {
  final b = BasePdf(recursos);
  final apaisado = doc.apaisado ?? doc.tablas.any((x) => x.columnas.length > 6);
  final formato = (apaisado ? PdfPageFormat.a4.landscape : PdfPageFormat.a4).copyWith(
    marginLeft: 22,
    marginRight: 22,
    marginTop: 18,
    marginBottom: 18,
  );
  final marca = doc.marcaAgua?.trim() ?? '';
  final tema = pw.PageTheme(
    pageFormat: formato,
    theme: b.tema,
    buildForeground: marca.isEmpty ? null : (_) => _marcaAgua(b, marca),
  );

  final pdf = pw.Document(
    theme: b.tema,
    title: '${MarcaExport.empresa} — ${doc.titulo}',
    author: 'AgroSoft J&L · ${doc.operario}',
    creator: MarcaExport.pie,
    producer: 'AgroSoft J&L',
    subject: [if (doc.subtitulo != null && doc.subtitulo!.isNotEmpty) doc.subtitulo!, 'Folio ${doc.folio}'].join(' · '),
    keywords: 'COMEX, CECO, AgroSoft J&L, ${doc.folio}',
  );

  if (doc.portada) {
    pdf.addPage(pw.Page(pageTheme: tema, build: (ctx) => _portada(b, doc, ctx)));
  }

  final tablas = doc.tablas.isEmpty
      ? [
          TablaExport(titulo: doc.titulo, columnas: const [ColumnaExport('Sin datos')], filas: const []),
        ]
      : doc.tablas;
  // Hoja donde quedó cada sección (la última vez que se acomodó: un bloque que no entra se rearma en la siguiente).
  final paginas = <int, PdfPage>{};

  // Corridas: cada tabla con hojaNueva abre una; las demás siguen debajo de la anterior.
  final corridas = <List<int>>[];
  for (var i = 0; i < tablas.length; i++) {
    if (i == 0 || tablas[i].hojaNueva) {
      corridas.add([i]);
    } else {
      corridas.last.add(i);
    }
  }
  // Hoja de contenido sólo si hay más de una corrida (todo seguido en una hoja, p. ej. una receta, no la lleva).
  final conContenido = corridas.length > 1;
  if (conContenido) {
    pdf.addPage(pw.Page(pageTheme: tema, build: (ctx) => _contenido(b, doc, tablas, paginas, ctx)));
  }
  // Sin portada ni hoja de contenido, el resumen va arriba de la primera sección.
  final kpisArriba = !doc.portada && !conContenido && doc.resumen.isNotEmpty;
  for (final corrida in corridas) {
    final registros = corrida.fold<int>(0, (a, i) => a + tablas[i].filas.length);
    final numero = '$registros registro${registros == 1 ? '' : 's'}';
    final inicial = corrida.first == 0;
    pdf.addPage(
      pw.MultiPage(
        pageTheme: tema,
        maxPages: 5000,
        header: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: b.encabezado(
            titulo: doc.titulo.toUpperCase(),
            numero: numero,
            folio: doc.folio,
            datos: [
              [
                if (conContenido) corrida.map((i) => tablas[i].titulo).join(' · '),
                if (doc.subtitulo != null && doc.subtitulo!.isNotEmpty) doc.subtitulo!,
              ].join('  ·  '),
              'Emitido ${fechaHoraExport(doc.emitido)}  ·  Operario: ${doc.operario}',
            ],
          ),
        ),
        footer: (ctx) => b.pie(ctx, emitido: doc.emitido, extra: 'Folio ${doc.folio}'),
        build: (_) => [
          if (inicial && kpisArriba) ...[
            b.tarjetasKpi(doc.resumen, porFila: apaisado ? 5 : 4),
            pw.SizedBox(height: 12),
          ],
          if (inicial && doc.graficos.isNotEmpty)
            ..._grillaGraficos(b, [for (final g in doc.graficos) (g, datosDeGrafico(g))], apaisado),
          for (final i in corrida) ...[
            if (i != corrida.first) pw.SizedBox(height: 12),
            ..._seccion(
              paginas,
              b,
              tablas[i],
              i,
              apaisado,
              formato.availableWidth,
              titulo: tablas.length > 1 || tablas[i].subtitulo != null,
            ),
          ],
          if (corrida.last == tablas.length - 1 && doc.firmas.isNotEmpty) ...[
            pw.SizedBox(height: 4), // la firma ya deja su espacio arriba de la línea
            pw.Row(children: [for (final f in doc.firmas) b.firma(f)]),
          ],
        ],
      ),
    );
  }
  return pdf.save();
}

/// Anota en qué hoja quedó la sección (cada vez que se acomoda; vale la última).
class _RegistroHoja extends pw.Widget {
  _RegistroHoja(this.paginas, this.seccion);

  final Map<int, PdfPage> paginas;
  final int seccion;

  @override
  void layout(pw.Context context, pw.BoxConstraints constraints, {bool parentUsesSize = false}) {
    paginas[seccion] = context.page;
    box = PdfRect.zero;
  }
}

/// Ancla de la sección [i] (marcadores y hoja de contenido).
String _ancla(int i) => 'seccion_$i';

List<pw.Widget> _seccion(
  Map<int, PdfPage> paginas,
  BasePdf b,
  TablaExport tabla,
  int i,
  bool apaisado,
  double ancho, {
  required bool titulo,
}) {
  final graficos = [for (final g in tabla.graficos) (g, datosDeGrafico(g, tabla))];
  final conGraficos = graficos.any((x) => !x.$2.vacio);
  final ancla = pw.Outline(
    name: _ancla(i),
    title: b.t(tabla.titulo),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [_RegistroHoja(paginas, i), if (titulo || conGraficos) _tituloTabla(b, tabla)],
    ),
  );
  final filasGraficos = _grillaGraficos(b, graficos, apaisado);
  return [
    // El título va pegado a la primera fila de gráficos (no queda solo al pie de una hoja).
    if (filasGraficos.isEmpty)
      ancla
    else
      pw.Inseparable(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [ancla, filasGraficos.first]),
      ),
    ...filasGraficos.skip(1),
    if (tabla.filas.isEmpty)
      pw.Padding(
        padding: const pw.EdgeInsets.all(24),
        child: pw.Center(child: b.texto('Sin registros para mostrar.', tam: 9, color: ColoresPdf.gris)),
      )
    else
      b.tablaExport(tabla, ancho: ancho),
  ];
}

/// Gráficos en grilla: uno a todo el ancho, o de a dos (de a tres en apaisado con 3 o más).
List<pw.Widget> _grillaGraficos(BasePdf b, List<(GraficoExport, DatosGrafico)> graficos, bool apaisado) {
  final validos = graficos.where((x) => !x.$2.vacio).toList();
  if (validos.isEmpty) return const [];
  final porFila = validos.length == 1 ? 1 : (apaisado && validos.length >= 3 ? 3 : 2);
  final alto = porFila == 1 ? (apaisado ? 190.0 : 215.0) : (porFila == 2 ? 190.0 : 180.0);
  return [
    for (var i = 0; i < validos.length; i += porFila)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var k = 0; k < porFila; k++) ...[
              if (k > 0) pw.SizedBox(width: 10),
              pw.Expanded(
                child: i + k < validos.length
                    ? graficoPdf(b, validos[i + k].$1, validos[i + k].$2, alto: alto)
                    : pw.SizedBox(),
              ),
            ],
          ],
        ),
      ),
  ];
}

pw.Widget _marcaAgua(BasePdf b, String texto) => pw.Center(
  child: pw.Transform.rotate(
    angle: math.pi / 7,
    child: pw.Opacity(
      opacity: 0.12,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: ColoresPdf.rojo, width: 5),
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Text(
          b.t(texto.toUpperCase()),
          style: pw.TextStyle(fontSize: 90, color: ColoresPdf.rojo, fontWeight: pw.FontWeight.bold, letterSpacing: 6),
        ),
      ),
    ),
  ),
);

pw.Widget _tituloTabla(BasePdf b, TablaExport tabla) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 8),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(width: 3, height: 22, color: ColoresPdf.verde),
      pw.SizedBox(width: 6),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            b.texto(tabla.titulo, tam: 11, negrita: true, color: ColoresPdf.verdeOscuro),
            if (tabla.subtitulo != null) b.texto(tabla.subtitulo!, tam: 7.5, color: ColoresPdf.gris),
          ],
        ),
      ),
      b.texto('${tabla.filas.length} registro${tabla.filas.length == 1 ? '' : 's'}', tam: 7.5, color: ColoresPdf.gris),
    ],
  ),
);

String _plural(int n, String uno, String varios) => '$n ${n == 1 ? uno : varios}';

/// Hoja de contenido: resumen (si no hay portada) y número, título, detalle, registros y hoja de cada sección
/// (con vínculo a la sección).
pw.Widget _contenido(
  BasePdf b,
  DocumentoExport doc,
  List<TablaExport> tablas,
  Map<int, PdfPage> paginas,
  pw.Context ctx,
) {
  String? hojaDe(int i) {
    final p = paginas[i];
    final n = p == null ? -1 : ctx.document.pdfPageList.pages.indexOf(p);
    return n < 0 ? null : '${n + 1}';
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      b.encabezado(
        titulo: doc.titulo.toUpperCase(),
        numero: 'Contenido',
        folio: doc.folio,
        datos: [doc.subtitulo ?? '', 'Emitido ${fechaHoraExport(doc.emitido)}  ·  Operario: ${doc.operario}'],
      ),
      pw.SizedBox(height: 16),
      if (!doc.portada && doc.resumen.isNotEmpty) ...[
        b.texto('RESUMEN DEL INFORME', tam: 8, color: ColoresPdf.verde, negrita: true),
        pw.SizedBox(height: 6),
        b.tarjetasKpi(doc.resumen, porFila: ctx.page.pageFormat.availableWidth > 600 ? 5 : 4),
        pw.SizedBox(height: 18),
      ],
      b.texto('CONTENIDO DEL INFORME', tam: 8, color: ColoresPdf.verde, negrita: true),
      pw.SizedBox(height: 4),
      for (var i = 0; i < tablas.length; i++)
        pw.Link(
          destination: _ancla(i),
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: ColoresPdf.linea, width: 0.5)),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 18,
                  height: 18,
                  alignment: pw.Alignment.center,
                  decoration: const pw.BoxDecoration(color: ColoresPdf.verde, shape: pw.BoxShape.circle),
                  child: b.texto('${i + 1}', tam: 7.5, color: PdfColors.white, negrita: true),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      b.texto(tablas[i].titulo, tam: 10, negrita: true, color: ColoresPdf.verdeOscuro, lineas: 1),
                      if (tablas[i].subtitulo != null)
                        b.texto(tablas[i].subtitulo!, tam: 7.2, color: ColoresPdf.gris, lineas: 1),
                    ],
                  ),
                ),
                b.texto(
                  [
                    _plural(tablas[i].filas.length, 'registro', 'registros'),
                    if (tablas[i].graficos.isNotEmpty) _plural(tablas[i].graficos.length, 'gráfico', 'gráficos'),
                  ].join('  ·  '),
                  tam: 7.5,
                  color: ColoresPdf.gris,
                ),
                pw.SizedBox(width: 14),
                pw.SizedBox(
                  width: 50,
                  height: 12,
                  child: pw.DelayedWidget(
                    build: (_) => b.texto(
                      'Hoja ${hojaDe(i) ?? '-'}',
                      tam: 8.5,
                      negrita: true,
                      color: ColoresPdf.verde,
                      alinear: pw.TextAlign.right,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      pw.Spacer(),
      b.pie(ctx, emitido: doc.emitido, extra: 'Folio ${doc.folio}'),
    ],
  );
}

/// Portada del informe ejecutivo: logo, título, datos de emisión con el código de barras y el resumen en tarjetas.
pw.Widget _portada(BasePdf b, DocumentoExport doc, pw.Context ctx) {
  final ancho = ctx.page.pageFormat.availableWidth;
  final porFila = ancho > 600 ? 4 : 3;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(height: 3, color: ColoresPdf.verde),
      pw.Spacer(),
      pw.Center(child: b.logoEmpresa(96)),
      pw.SizedBox(height: 14),
      pw.Center(
        child: b.texto('${MarcaExport.empresa}  ·  ${MarcaExport.sub}', tam: 10, color: ColoresPdf.gris, negrita: true),
      ),
      pw.SizedBox(height: 8),
      pw.Center(
        child: b.texto(
          doc.titulo.toUpperCase(),
          tam: 24,
          negrita: true,
          color: ColoresPdf.verdeOscuro,
          alinear: pw.TextAlign.center,
        ),
      ),
      if (doc.subtitulo != null && doc.subtitulo!.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        pw.Center(
          child: b.texto(doc.subtitulo!, tam: 10.5, color: ColoresPdf.gris, alinear: pw.TextAlign.center),
        ),
      ],
      pw.SizedBox(height: 12),
      pw.Center(child: pw.Container(width: 48, height: 2.5, color: ColoresPdf.verde)),
      pw.SizedBox(height: 22),
      if (doc.resumen.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 30),
          child: b.tarjetasKpi(doc.resumen, porFila: porFila),
        ),
      pw.Spacer(),
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: pw.BoxDecoration(
          color: ColoresPdf.grisClaro,
          border: pw.Border.all(color: ColoresPdf.linea),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  b.texto('INFORME EJECUTIVO', tam: 7.5, color: ColoresPdf.verde, negrita: true),
                  pw.SizedBox(height: 3),
                  b.texto('Emitido ${fechaHoraExport(doc.emitido)}  ·  Generado por ${doc.operario}', tam: 9),
                  if (doc.tablas.isNotEmpty)
                    b.texto(
                      '${_plural(doc.tablas.length, 'sección', 'secciones')}  ·  '
                      '${_plural(doc.totalFilas, 'registro', 'registros')}',
                      tam: 8,
                      color: ColoresPdf.gris,
                    ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                b.codigoBarras(doc.folio, ancho: 170, alto: 26),
                pw.SizedBox(height: 2),
                b.texto(doc.folio, tam: 7, color: ColoresPdf.gris),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 8),
      b.pie(ctx, emitido: doc.emitido),
    ],
  );
}
