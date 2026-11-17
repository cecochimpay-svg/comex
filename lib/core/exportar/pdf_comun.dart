import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'modelo.dart';

/// Piezas comunes de los PDF (informes y remitos), con la estética de los PDF de oficina de AgroSoft J&L:
/// franja verde, membrete gris claro con logo, título y código de barras del folio, tablas con encabezado
/// verde y filas alternadas, cajas de resumen, firmas y pie institucional con el logo del sistema.
/// Los colores son propios (el PDF es siempre claro, no sigue el tema de la app).

/// Recursos del PDF (bytes, para poder generar fuera del hilo de la pantalla).
/// Sin fuentes se usa Helvetica y los caracteres fuera de Latin-1 se reemplazan.
class RecursosPdf {
  const RecursosPdf({this.logo, this.fuente, this.fuenteNegrita, this.logoSistema, this.fuenteSimbolos});

  /// Logo de la empresa (membrete).
  final Uint8List? logo;
  final Uint8List? fuente;
  final Uint8List? fuenteNegrita;

  /// Logo de AgroSoft J&L (pie).
  final Uint8List? logoSistema;

  /// Respaldo para los símbolos que Noto Sans no trae (flechas, ✓, ●, ▲, ★…): DejaVu Sans recortada.
  final Uint8List? fuenteSimbolos;
}

abstract final class ColoresPdf {
  static const verde = PdfColor.fromInt(MarcaExport.verde);
  static const verdeOscuro = PdfColor.fromInt(MarcaExport.verdeOscuro);
  static const verdeClaro = PdfColor.fromInt(0xFFE8F2EC);
  static const gris = PdfColor.fromInt(0xFF556358);
  static const grisClaro = PdfColor.fromInt(0xFFF4F6F4);
  static const linea = PdfColor.fromInt(0xFFD2D7D3);
  static const tinta = PdfColor.fromInt(0xFF1B231D);
  static const rojo = PdfColor.fromInt(0xFFC62828);
  static const naranja = PdfColor.fromInt(0xFFE08600);
}

/// Pie institucional de todos los PDF.
const pieInstitucionalPdf = 'COMEX · CECO S.A. · Sistemas AgroSoft J&L';

/// Fuentes, logos y texto seguro para un documento.
class BasePdf {
  BasePdf(RecursosPdf r)
    : _conFuente = r.fuente != null,
      _conSimbolos = r.fuente != null && r.fuenteSimbolos != null,
      tema = r.fuente != null
          ? pw.ThemeData.withFont(
              base: pw.Font.ttf(r.fuente!.buffer.asByteData()),
              bold: pw.Font.ttf((r.fuenteNegrita ?? r.fuente!).buffer.asByteData()),
              fontFallback: [if (r.fuenteSimbolos != null) pw.Font.ttf(r.fuenteSimbolos!.buffer.asByteData())],
            )
          : pw.ThemeData.base(),
      logo = r.logo == null ? null : pw.MemoryImage(r.logo!),
      logoSistema = r.logoSistema == null ? null : pw.MemoryImage(r.logoSistema!);

  final bool _conFuente;
  final bool _conSimbolos;
  final pw.ThemeData tema;
  final pw.ImageProvider? logo;
  final pw.ImageProvider? logoSistema;

  /// Texto listo para dibujar en widgets: sin fuente TTF, Helvetica sólo tiene Latin-1; con Noto Sans y sin el
  /// respaldo de símbolos, las flechas / tildes / figuras se cambian por equivalentes que sí tiene.
  String t(String s) => !_conFuente ? latin1Pdf(s) : (_conSimbolos ? s : simbolosSegurosPdf(s));

  /// Texto para dibujar directo en el lienzo (gráficos): ahí no hay respaldo de fuente.
  String tSeguro(String s) => _conFuente ? simbolosSegurosPdf(s) : latin1Pdf(s);

  pw.Text texto(
    String s, {
    double tam = 8,
    PdfColor color = ColoresPdf.tinta,
    bool negrita = false,
    pw.TextAlign? alinear,
    int? lineas,
  }) => pw.Text(
    t(s),
    textAlign: alinear,
    maxLines: lineas,
    style: pw.TextStyle(fontSize: tam, color: color, fontWeight: negrita ? pw.FontWeight.bold : null),
  );

  /// Membrete: franja verde, logo, empresa, título y renglones a la izquierda; número, código de barras
  /// del folio y el folio a la derecha.
  pw.Widget encabezado({
    required String titulo,
    required String numero,
    required String folio,
    List<String> datos = const [],
  }) => pw.Column(
    children: [
      pw.Container(height: 3, color: ColoresPdf.verde),
      pw.Container(
        color: ColoresPdf.grisClaro,
        padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            _logo(54),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  texto(
                    '${MarcaExport.empresa}  ·  ${MarcaExport.sub}',
                    tam: 8.5,
                    color: ColoresPdf.gris,
                    negrita: true,
                  ),
                  pw.SizedBox(height: 2),
                  texto(titulo, tam: 16, color: ColoresPdf.verdeOscuro, negrita: true, lineas: 2),
                  pw.SizedBox(height: 2),
                  for (final d in datos.where((d) => d.trim().isNotEmpty))
                    texto(d, tam: 7.8, color: ColoresPdf.gris, lineas: 2),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                texto(numero, tam: 15, color: ColoresPdf.verde, negrita: true),
                pw.SizedBox(height: 4),
                codigoBarras(folio, ancho: 150, alto: 24),
                pw.SizedBox(height: 2),
                texto(folio, tam: 6.5, color: ColoresPdf.gris),
              ],
            ),
          ],
        ),
      ),
      pw.Container(height: 1, color: ColoresPdf.verde),
    ],
  );

  pw.Widget _logo(double lado) => logo != null
      ? pw.SizedBox(
          width: lado,
          height: lado,
          child: pw.Image(logo!, fit: pw.BoxFit.contain),
        )
      : pw.Container(
          width: lado,
          height: lado,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: ColoresPdf.linea),
            borderRadius: pw.BorderRadius.circular(4),
          ),
        );

  pw.Widget logoEmpresa(double lado) => _logo(lado);

  pw.Widget codigoBarras(String dato, {double ancho = 150, double alto = 24}) => pw.SizedBox(
    width: ancho,
    height: alto,
    child: pw.BarcodeWidget(
      barcode: pw.Barcode.code128(),
      data: dato.replaceAll(RegExp(r'[^\x20-\x7E]'), '-'), // code128: sólo ASCII imprimible
      drawText: false,
      color: ColoresPdf.verdeOscuro,
    ),
  );

  /// Pie: logo del sistema, leyenda institucional, emisión y "Hoja n de m".
  pw.Widget pie(pw.Context ctx, {required DateTime emitido, String extra = ''}) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 6),
    padding: const pw.EdgeInsets.only(top: 4),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: ColoresPdf.linea, width: 0.6)),
    ),
    child: pw.Row(
      children: [
        if (logoSistema != null) ...[
          pw.SizedBox(width: 14, height: 14, child: pw.Image(logoSistema!)),
          pw.SizedBox(width: 6),
        ],
        pw.Expanded(
          child: texto(
            '$pieInstitucionalPdf${extra.isEmpty ? '' : ' · $extra'}',
            tam: 6.5,
            color: ColoresPdf.gris,
            negrita: true,
          ),
        ),
        texto(
          'Emitido ${fechaHoraExport(emitido)} · Hoja ${ctx.pageNumber} de ${ctx.pagesCount}',
          tam: 6.5,
          color: ColoresPdf.gris,
        ),
      ],
    ),
  );

  /// Tarjeta con título en pastilla, dato principal y renglones (empresa, destino, transporte…).
  pw.Widget tarjeta(String titulo, String principal, List<String> renglones, {PdfColor color = ColoresPdf.verde}) =>
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: ColoresPdf.linea, width: 0.8),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pastilla(titulo, color: color),
            pw.SizedBox(height: 5),
            texto(principal.trim().isEmpty ? '-' : principal, tam: 10, negrita: true, color: ColoresPdf.verdeOscuro),
            pw.SizedBox(height: 2),
            for (final r in renglones.where((x) => x.trim().isNotEmpty))
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 1.2),
                child: texto(r, tam: 7.6, color: ColoresPdf.gris),
              ),
          ],
        ),
      );

  pw.Widget pastilla(String s, {PdfColor color = ColoresPdf.verde, double tam = 6.5}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
    decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(3)),
    child: texto(s.toUpperCase(), tam: tam, color: PdfColors.white, negrita: true),
  );

  /// Caja gris con un título verde y pares (concepto, valor) en columnas.
  pw.Widget cajaResumen(String titulo, List<(String, String)> pares, {double anchoDato = 118}) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 8),
    decoration: pw.BoxDecoration(
      color: ColoresPdf.grisClaro,
      border: pw.Border.all(color: ColoresPdf.linea),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        texto(titulo.toUpperCase(), tam: 7.5, color: ColoresPdf.verde, negrita: true),
        pw.SizedBox(height: 5),
        pw.Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            for (final (k, v) in pares)
              pw.SizedBox(
                width: anchoDato,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    texto(k.toUpperCase(), tam: 6.4, color: ColoresPdf.gris),
                    texto(v, tam: 10.5, negrita: true, color: ColoresPdf.verdeOscuro),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );

  /// Línea de firma con rol y aclaración.
  pw.Widget firma(String rol, {String? nombre}) => pw.Expanded(
    child: pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14),
      child: pw.Column(
        children: [
          pw.SizedBox(height: 24),
          pw.Container(height: 0.8, color: ColoresPdf.tinta),
          pw.SizedBox(height: 3),
          texto(rol, tam: 8, negrita: true),
          texto(
            nombre == null || nombre.trim().isEmpty ? 'Firma y aclaración' : nombre,
            tam: 6.8,
            color: ColoresPdf.gris,
          ),
        ],
      ),
    ),
  );

  /// Tarjetas de indicadores (el resumen): rótulo chico en mayúsculas, valor grande y acento verde a la
  /// izquierda; [porFila] por renglón.
  pw.Widget tarjetasKpi(List<(String, String)> pares, {int porFila = 4}) {
    pw.Widget tarjeta((String, String) p) => pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(9, 6, 8, 7),
      decoration: const pw.BoxDecoration(
        color: ColoresPdf.grisClaro,
        border: pw.Border(left: pw.BorderSide(color: ColoresPdf.verde, width: 2.5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          texto(p.$1.toUpperCase(), tam: 6.3, color: ColoresPdf.gris, negrita: true, lineas: 1),
          pw.SizedBox(height: 2.5),
          texto(p.$2, tam: 12.5, color: ColoresPdf.verdeOscuro, negrita: true, lineas: 1),
        ],
      ),
    );
    // Renglones parejos: 5 tarjetas con 4 por fila salen 3 + 2, no 4 + 1.
    if (pares.isNotEmpty) porFila = (pares.length / (pares.length / porFila).ceil()).ceil();
    final filas = <pw.Widget>[];
    for (var i = 0; i < pares.length; i += porFila) {
      final grupo = pares.skip(i).take(porFila).toList();
      filas.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(top: i == 0 ? 0 : 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var k = 0; k < porFila; k++) ...[
                if (k > 0) pw.SizedBox(width: 6),
                pw.Expanded(child: k < grupo.length ? tarjeta(grupo[k]) : pw.SizedBox()),
              ],
            ],
          ),
        ),
      );
    }
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: filas);
  }

  /// Tabla con encabezado verde, filas alternadas, renglón de totales y anchos según el contenido.
  /// [compacta]: menos aire por fila (listados largos); [numerar]: columna "Nº" al principio.
  pw.Widget tabla(
    List<ColumnaExport> cols,
    List<List<Object?>> filas, {
    List<Object?>? totales,
    double? tam,
    bool numerar = false,
    bool compacta = false,
  }) => _tabla(cols, [_BloquePdf(null, filas, null)], totales: totales, tam: tam, numerar: numerar, compacta: compacta);

  /// Tabla de un informe: con [TablaExport.agruparPor], cada grupo arranca con su encabezado pegado a la primera
  /// fila (nunca queda huérfano al pie de una hoja) y cierra con su subtotal; las filas anuladas salen tachadas.
  /// [ancho]: ancho disponible de la hoja (para que el rótulo del grupo cruce las columnas).
  pw.Widget tablaExport(TablaExport t, {bool compacta = true, double? tam, double? ancho}) {
    final g = t.agruparPor;
    final agrupada = g != null && g >= 0 && g < t.columnas.length && t.filas.isNotEmpty;
    final bloques = agrupada
        ? [
            for (final grupo in t.grupos)
              _BloquePdf(
                '${t.columnas[g].titulo}: ${grupo.clave}  ·  ${grupo.filas.length} '
                'registro${grupo.filas.length == 1 ? '' : 's'}',
                grupo.filas,
                (grupo.rotuloSubtotal, grupo.columnaRotulo, grupo.subtotales),
              ),
          ]
        : [_BloquePdf(null, t.filas, null)];
    final tot = t.filaTotales;
    final totales = agrupada && t.totales == null && tot != null && tot.isNotEmpty && tot.first == 'TOTALES'
        ? ['TOTAL GENERAL', ...tot.skip(1)]
        : tot;
    return _tabla(
      t.columnas,
      bloques,
      totales: totales,
      tam: tam,
      compacta: compacta,
      anulada: t.anulada,
      ancho: ancho,
    );
  }

  pw.Widget _tabla(
    List<ColumnaExport> cols,
    List<_BloquePdf> bloques, {
    List<Object?>? totales,
    double? tam,
    bool numerar = false,
    bool compacta = false,
    bool Function(List<Object?>)? anulada,
    double? ancho,
  }) {
    final t0 = tam ?? (cols.length > 9 ? 6.6 : 7.4);
    List<String> textosDe(List<Object?> f) => [
      for (var c = 0; c < cols.length; c++) t(c < f.length ? textoCelda(f[c], cols[c]) : ''),
    ];
    final textos = [
      for (final b in bloques) [for (final f in b.filas) textosDe(f)],
    ];
    final textosTot = totales == null
        ? null
        : [
            for (var c = 0; c < cols.length; c++)
              c >= totales.length || totales[c] == null
                  ? ''
                  : t(totales[c] is String ? totales[c] as String : textoCelda(totales[c], cols[c])),
          ];

    // Ancho de cada columna según el largo típico de su contenido (muestra de filas).
    final anchos = <int, pw.TableColumnWidth>{};
    final desplazamiento = numerar ? 1 : 0;
    if (numerar) anchos[0] = const pw.FixedColumnWidth(20);
    final muestra = textos.expand((x) => x).take(400).toList();
    for (var c = 0; c < cols.length; c++) {
      var largo = cols[c].titulo.length * 0.8;
      var suma = 0.0;
      for (final f in muestra) {
        if (f[c].length > largo) largo = f[c].length > 34 ? 34 : f[c].length.toDouble();
        suma += f[c].length;
      }
      final promedio = muestra.isEmpty ? largo : suma / muestra.length;
      // El encabezado (mayúsculas en negrita) puede partirse en renglones, pero no en medio de una palabra.
      final palabra = cols[c].titulo.split(RegExp(r'\s+')).fold<int>(0, (a, w) => w.length > a ? w.length : a) * 1.2;
      final flex = ((largo + promedio) / 2).clamp(4, 30).toDouble();
      anchos[c + desplazamiento] = pw.FlexColumnWidth(flex < palabra ? palabra : flex);
    }

    // Posición x de cada columna (la tabla reparte el ancho en proporción a los flex): el rótulo de un grupo o de
    // un subtotal se dibuja en pedazos, uno por celda, corrido según la columna (cada celda recorta lo suyo).
    final xs = <double>[];
    if (ancho != null) {
      final totalFlex = [for (var c = 0; c < cols.length; c++) (anchos[c + desplazamiento]! as pw.FlexColumnWidth).flex]
          .fold<double>(0, (a, f) => a + f);
      final porFlex = (ancho - (numerar ? 20 : 0)) / totalFlex;
      var x = 0.0;
      if (numerar) {
        xs.add(0);
        x = 20;
      }
      for (var c = 0; c < cols.length; c++) {
        xs.add(x);
        x += (anchos[c + desplazamiento]! as pw.FlexColumnWidth).flex * porFlex;
      }
    }
    pw.Widget pedazo(String texto, int columna, int desde, double alto, pw.TextStyle estilo, {double abajo = 0}) {
      final corrido = xs.isEmpty ? (columna == desde ? 0.0 : null) : xs[columna] - xs[desde];
      return pw.SizedBox(
        height: alto,
        child: corrido == null
            ? null
            : pw.Stack(
                overflow: pw.Overflow.visible,
                children: [
                  pw.Positioned(
                    left: 4 - corrido,
                    bottom: abajo,
                    child: pw.Text(texto, softWrap: false, maxLines: 1, style: estilo),
                  ),
                ],
              ),
      );
    }

    pw.TextAlign alineacion(ColumnaExport c) =>
        c.tipo == TipoDato.fecha ? pw.TextAlign.center : (c.numerica ? pw.TextAlign.right : pw.TextAlign.left);

    bool negativo(Object? v, ColumnaExport c) {
      if (!c.numerica || v == null) return false;
      if (v is num) return v < 0;
      final n = double.tryParse(v.toString().trim().replaceAll(',', '.'));
      return n != null && n < 0;
    }

    pw.Widget celda(
      String s, {
      pw.TextAlign alinear = pw.TextAlign.left,
      PdfColor color = ColoresPdf.tinta,
      bool negrita = false,
      bool tachado = false,
      double? tamano,
    }) => pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: compacta ? 2.2 : 3),
      child: pw.Text(
        s,
        textAlign: alinear,
        style: pw.TextStyle(
          fontSize: tamano ?? t0,
          color: color,
          fontWeight: negrita ? pw.FontWeight.bold : null,
          decoration: tachado ? pw.TextDecoration.lineThrough : null,
        ),
      ),
    );

    // Encabezado de grupo pegado arriba de la primera fila (una sola fila de la tabla: no se separan).
    final altoBanda = t0 + 9;
    final estiloBanda = pw.TextStyle(fontSize: t0 + 0.4, color: ColoresPdf.verdeOscuro, fontWeight: pw.FontWeight.bold);
    pw.Widget conBanda(pw.Widget hijo, int columna, String? rotulo) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFEAF3EE),
            border: pw.Border(bottom: pw.BorderSide(color: ColoresPdf.verde, width: 0.9)),
          ),
          child: rotulo == null
              ? pw.SizedBox(height: altoBanda)
              : pedazo(t(rotulo), columna, 0, altoBanda, estiloBanda, abajo: 3),
        ),
        hijo,
      ],
    );

    final filasTabla = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: ColoresPdf.verde),
        children: [
          if (numerar) celda('Nº', alinear: pw.TextAlign.center, color: PdfColors.white, negrita: true),
          for (final c in cols)
            celda(
              t(c.titulo.toUpperCase()),
              alinear: alineacion(c),
              color: PdfColors.white,
              negrita: true,
              tamano: t0 - 0.4,
            ),
        ],
      ),
    ];
    var numero = 0;
    for (var b = 0; b < bloques.length; b++) {
      final bloque = bloques[b];
      final filas = bloque.filas;
      if (bloque.rotulo != null && filas.isEmpty) {
        filasTabla.add(
          pw.TableRow(
            children: [
              for (var c = 0; c < cols.length + desplazamiento; c++) conBanda(pw.SizedBox(), c, bloque.rotulo),
            ],
          ),
        );
      }
      for (var i = 0; i < filas.length; i++) {
        numero++;
        final f = filas[i];
        final esAnulada = anulada?.call(f) ?? false;
        final primera = i == 0 && bloque.rotulo != null;
        pw.Widget envolver(pw.Widget w, int columna) => primera ? conBanda(w, columna, bloque.rotulo) : w;
        filasTabla.add(
          pw.TableRow(
            decoration: i.isOdd ? const pw.BoxDecoration(color: ColoresPdf.grisClaro) : null,
            children: [
              if (numerar) envolver(celda('$numero', alinear: pw.TextAlign.center, color: ColoresPdf.gris), 0),
              for (var c = 0; c < cols.length; c++)
                envolver(
                  celda(
                    textos[b][i][c],
                    alinear: alineacion(cols[c]),
                    tachado: esAnulada,
                    color: esAnulada
                        ? const PdfColor.fromInt(0xFF8A938C)
                        : (negativo(c < f.length ? f[c] : null, cols[c]) ? ColoresPdf.rojo : ColoresPdf.tinta),
                  ),
                  c + desplazamiento,
                ),
            ],
          ),
        );
      }
      final sub = bloque.subtotal;
      if (sub != null) {
        final (rotulo, colRotulo, valores) = sub;
        // El rótulo ocupa su columna y las siguientes que no llevan subtotal.
        var hasta = colRotulo;
        while (hasta + 1 < cols.length && (hasta + 1 >= valores.length || valores[hasta + 1] == null)) {
          hasta++;
        }
        final altoFila = t0 * 1.3 + (compacta ? 4.4 : 6);
        final estiloSub = pw.TextStyle(fontSize: t0, color: ColoresPdf.verdeOscuro, fontWeight: pw.FontWeight.bold);
        filasTabla.add(
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF0F6F2),
              border: pw.Border(top: pw.BorderSide(color: ColoresPdf.verde, width: 0.6)),
            ),
            children: [
              if (numerar) celda(''),
              for (var c = 0; c < cols.length; c++)
                c >= colRotulo && c <= hasta
                    ? pedazo(t(rotulo), c + desplazamiento, colRotulo + desplazamiento, altoFila, estiloSub, abajo: 3.5)
                    : celda(
                        c < valores.length && valores[c] != null ? t(textoCelda(valores[c], cols[c])) : '',
                        alinear: alineacion(cols[c]),
                        negrita: true,
                        color: negativo(c < valores.length ? valores[c] : null, cols[c])
                            ? ColoresPdf.rojo
                            : ColoresPdf.verdeOscuro,
                      ),
            ],
          ),
        );
      }
    }
    if (textosTot != null) {
      filasTabla.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: ColoresPdf.verdeClaro,
            border: pw.Border(top: pw.BorderSide(color: ColoresPdf.verde, width: 1)),
          ),
          children: [
            if (numerar) celda(''),
            for (var c = 0; c < cols.length; c++)
              celda(
                textosTot[c],
                alinear: c < totales!.length && totales[c] is String ? pw.TextAlign.left : alineacion(cols[c]),
                color: negativo(c < totales.length ? totales[c] : null, cols[c])
                    ? ColoresPdf.rojo
                    : ColoresPdf.verdeOscuro,
                negrita: true,
              ),
          ],
        ),
      );
    }

    return pw.Table(
      columnWidths: anchos,
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: ColoresPdf.linea, width: 0.4),
        bottom: pw.BorderSide(color: ColoresPdf.linea, width: 0.4),
      ),
      children: filasTabla,
    );
  }
}

/// Tramo de una tabla: filas con encabezado de grupo y subtotal opcionales.
class _BloquePdf {
  const _BloquePdf(this.rotulo, this.filas, this.subtotal);

  final String? rotulo;
  final List<List<Object?>> filas;

  /// (rótulo, columna del rótulo, valores).
  final (String, int, List<Object?>)? subtotal;
}

/// Sin fuente TTF: Helvetica sólo dibuja Latin-1.
String latin1Pdf(String s) {
  const reemplazos = {'—': '-', '–': '-', '“': '"', '”': '"', '‘': "'", '’': "'", '…': '...', '•': '·', '€': 'EUR'};
  final sb = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    sb.write(r <= 0xFF ? ch : (reemplazos[ch] ?? _simbolo(r) ?? '?'));
  }
  return sb.toString();
}

/// Con Noto Sans y sin fuente de símbolos: flechas, tildes y figuras por equivalentes que la fuente sí tiene.
String simbolosSegurosPdf(String s) {
  if (!s.runes.any((r) => r >= 0x2190 && r <= 0x2BFF)) return s;
  final sb = StringBuffer();
  for (final r in s.runes) {
    sb.write(r >= 0x2190 && r <= 0x2BFF ? (_simbolo(r) ?? '•') : String.fromCharCode(r));
  }
  return sb.toString();
}

const _simbolos = {
  0x2190: '<-', 0x2192: '->', 0x2191: '^', 0x2193: 'v', 0x2194: '<->', 0x21D0: '<=', 0x21D2: '=>', 0x21D4: '<=>', //
  0x2794: '->', 0x279C: '->', 0x27A1: '->', 0x2B05: '<-', 0x2B06: '^', 0x2B07: 'v', 0x27F6: '->', 0x27F5: '<-',
  0x2713: 'OK', 0x2714: 'OK', 0x2705: 'OK', 0x2611: '[x]', 0x2610: '[ ]', 0x2717: 'X', 0x2718: 'X', 0x274C: 'X',
  0x25CF: '•', 0x25CB: 'o', 0x25A0: '•', 0x25A1: '-', 0x25AA: '•', 0x25B2: '^', 0x25BC: 'v', 0x25B8: '>',
  0x25B6: '>', 0x25BA: '>', 0x25C0: '<', 0x25C2: '<', 0x2605: '*', 0x2606: '*', 0x26A0: '(!)', 0x2022: '•',
  0x2212: '-', 0x2264: '<=', 0x2265: '>=', 0x2260: '!=', 0x2248: '~',
};

String? _simbolo(int r) {
  final s = _simbolos[r];
  if (s != null) return s;
  if (r >= 0x2190 && r <= 0x21FF) return '->';
  return null;
}
