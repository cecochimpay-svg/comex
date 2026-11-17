import 'grafico.dart';

/// Gráfico nativo de Excel (DrawingML `xl/charts/chartN.xml`), anclado a celdas de una hoja con un dibujo
/// (`xl/drawings/drawingN.xml`). Los datos se referencian por rango y además van en caché (se ven aunque el
/// visor no recalcule).

class SerieXlsx {
  const SerieXlsx({required this.nombre, required this.ref, required this.valores, required this.color});

  final String nombre;

  /// Rango de los valores con la hoja: `'Datos gráficos'!$B$5:$B$9`.
  final String ref;
  final List<num?> valores;

  /// RRGGBB.
  final String color;
}

class GraficoXlsx {
  const GraficoXlsx({
    required this.tipo,
    required this.titulo,
    required this.refCategorias,
    required this.categorias,
    required this.series,
    required this.columna,
    required this.fila,
    this.formato = 'General',
    this.coloresPuntos = const [],
    this.columnas = 9,
    this.filas = 20,
  });

  final TipoGrafico tipo;
  final String titulo;

  /// Rango de las categorías con la hoja.
  final String refCategorias;
  final List<String> categorias;
  final List<SerieXlsx> series;

  /// Código de formato de los valores (eje y etiquetas).
  final String formato;

  /// Torta / dona: color de cada porción (RRGGBB).
  final List<String> coloresPuntos;

  /// Esquina superior izquierda (base 0) y tamaño en celdas.
  final int columna;
  final int fila;
  final int columnas;
  final int filas;
}

/// Rango absoluto con la hoja: `'Mi hoja'!$A$1:$A$9` (columnas y filas base 0 / base 1 como Excel).
String rangoXlsx(String hoja, String col1, int fila1, String col2, int fila2) =>
    "'${hoja.replaceAll("'", "''")}'!\$$col1\$$fila1:\$$col2\$$fila2";

String _x(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

String _num(num v) {
  if (v is int) return '$v';
  if (v.isNaN || v.isInfinite) return '0';
  if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
  return v.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '');
}

const _tinta = '3D4A40';
const _grilla = 'E3E7E4';
const _ejeColor = 'B8C0BA';

String _relleno(String rgb) => '<a:solidFill><a:srgbClr val="$rgb"/></a:solidFill>';

String _txPr({int tam = 900, bool negrita = false, String color = _tinta, int? rotacion}) =>
    '<c:txPr><a:bodyPr${rotacion == null ? '' : ' rot="$rotacion" vert="horz"'}/><a:lstStyle/><a:p><a:pPr>'
    '<a:defRPr sz="$tam" b="${negrita ? 1 : 0}">${_relleno(color)}<a:latin typeface="Calibri"/></a:defRPr>'
    '</a:pPr><a:endParaRPr lang="es-AR"/></a:p></c:txPr>';

String _cat(GraficoXlsx g) {
  final b = StringBuffer('<c:cat><c:strRef><c:f>${_x(g.refCategorias)}</c:f><c:strCache>')
    ..write('<c:ptCount val="${g.categorias.length}"/>');
  for (var i = 0; i < g.categorias.length; i++) {
    b.write('<c:pt idx="$i"><c:v>${_x(g.categorias[i])}</c:v></c:pt>');
  }
  b.write('</c:strCache></c:strRef></c:cat>');
  return b.toString();
}

String _val(GraficoXlsx g, SerieXlsx s) {
  final b = StringBuffer('<c:val><c:numRef><c:f>${_x(s.ref)}</c:f><c:numCache>')
    ..write('<c:formatCode>${_x(g.formato)}</c:formatCode><c:ptCount val="${s.valores.length}"/>');
  for (var i = 0; i < s.valores.length; i++) {
    final v = s.valores[i];
    if (v != null) b.write('<c:pt idx="$i"><c:v>${_num(v)}</c:v></c:pt>');
  }
  b.write('</c:numCache></c:numRef></c:val>');
  return b.toString();
}

String _tx(String nombre) => '<c:tx><c:v>${_x(nombre)}</c:v></c:tx>';

String _sinEtiquetas() =>
    '<c:dLbls><c:showLegendKey val="0"/><c:showVal val="0"/><c:showCatName val="0"/><c:showSerName val="0"/>'
    '<c:showPercent val="0"/><c:showBubbleSize val="0"/></c:dLbls>';

String _etiquetasValor(GraficoXlsx g, {String? posicion}) =>
    '<c:dLbls><c:numFmt formatCode="${_x(g.formato)}" sourceLinked="0"/><c:spPr><a:noFill/><a:ln><a:noFill/></a:ln></c:spPr>'
    '${_txPr(tam: 800, color: _tinta)}${posicion == null ? '' : '<c:dLblPos val="$posicion"/>'}'
    '<c:showLegendKey val="0"/><c:showVal val="1"/><c:showCatName val="0"/><c:showSerName val="0"/>'
    '<c:showPercent val="0"/><c:showBubbleSize val="0"/></c:dLbls>';

String _ejes(GraficoXlsx g, {required bool horizontal, required bool lineas}) {
  const cat = 500001;
  const val = 500002;
  final rot = !horizontal && g.categorias.length > 6 ? -2700000 : null;
  return '<c:catAx><c:axId val="$cat"/><c:scaling><c:orientation val="${horizontal ? 'maxMin' : 'minMax'}"/></c:scaling>'
      '<c:delete val="0"/><c:axPos val="${horizontal ? 'l' : 'b'}"/><c:numFmt formatCode="General" sourceLinked="0"/>'
      '<c:majorTickMark val="none"/><c:minorTickMark val="none"/><c:tickLblPos val="nextTo"/>'
      '<c:spPr><a:ln w="9525">${_relleno(_ejeColor)}</a:ln></c:spPr>${_txPr(rotacion: rot)}'
      '<c:crossAx val="$val"/><c:crosses val="autoZero"/><c:auto val="1"/><c:lblAlgn val="ctr"/>'
      '<c:lblOffset val="100"/><c:noMultiLvlLbl val="0"/></c:catAx>'
      '<c:valAx><c:axId val="$val"/><c:scaling><c:orientation val="minMax"/>'
      '${!lineas && _sinNegativos(g) ? '<c:min val="0"/>' : ''}</c:scaling><c:delete val="0"/>'
      '<c:axPos val="${horizontal ? 'b' : 'l'}"/>'
      '<c:majorGridlines><c:spPr><a:ln w="6350">${_relleno(_grilla)}</a:ln></c:spPr></c:majorGridlines>'
      '<c:numFmt formatCode="${_x(_formatoEje(g.formato))}" sourceLinked="0"/>'
      '<c:majorTickMark val="none"/><c:minorTickMark val="none"/><c:tickLblPos val="nextTo"/>'
      '<c:spPr><a:ln><a:noFill/></a:ln></c:spPr>${_txPr(color: '6B766E')}'
      '<c:crossAx val="$cat"/><c:crosses val="${horizontal ? 'max' : 'autoZero'}"/>'
      '<c:crossBetween val="${lineas ? 'midCat' : 'between'}"/></c:valAx>';
}

/// En el eje, sólo la parte positiva del formato.
String _formatoEje(String f) => f.split(';').first;

bool _sinNegativos(GraficoXlsx g) => g.series.every((s) => s.valores.every((v) => v == null || v >= 0));

/// XML del gráfico.
String xmlGraficoXlsx(GraficoXlsx g) {
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
    ..write(
      '<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
    )
    ..write('<c:date1904 val="0"/><c:lang val="es-AR"/><c:roundedCorners val="0"/><c:chart>')
    ..write(
      '<c:title><c:tx><c:rich><a:bodyPr/><a:lstStyle/><a:p><a:pPr><a:defRPr sz="1200" b="1">${_relleno('123F2C')}'
      '</a:defRPr></a:pPr><a:r><a:rPr lang="es-AR" sz="1200" b="1">${_relleno('123F2C')}</a:rPr>'
      '<a:t>${_x(g.titulo)}</a:t></a:r></a:p></c:rich></c:tx><c:overlay val="0"/></c:title>',
    )
    ..write('<c:autoTitleDeleted val="0"/><c:plotArea><c:layout/>');

  final varias = g.series.length > 1;
  switch (g.tipo) {
    case TipoGrafico.torta || TipoGrafico.dona:
      final dona = g.tipo == TipoGrafico.dona;
      b.write(dona ? '<c:doughnutChart>' : '<c:pieChart>');
      b.write('<c:varyColors val="1"/>');
      if (g.series.isNotEmpty) {
        final s = g.series.first;
        b.write('<c:ser><c:idx val="0"/><c:order val="0"/>${_tx(s.nombre)}');
        for (var i = 0; i < g.categorias.length; i++) {
          final color = i < g.coloresPuntos.length ? g.coloresPuntos[i] : s.color;
          b.write(
            '<c:dPt><c:idx val="$i"/><c:bubble3D val="0"/><c:spPr>${_relleno(color)}'
            '<a:ln w="19050">${_relleno('FFFFFF')}</a:ln></c:spPr></c:dPt>',
          );
        }
        b.write(
          '<c:dLbls><c:numFmt formatCode="0%" sourceLinked="0"/><c:spPr><a:noFill/><a:ln><a:noFill/></a:ln></c:spPr>'
          '${_txPr(tam: 900, negrita: true, color: dona ? _tinta : 'FFFFFF')}'
          '${dona ? '' : '<c:dLblPos val="inEnd"/>'}<c:showLegendKey val="0"/><c:showVal val="0"/>'
          '<c:showCatName val="0"/><c:showSerName val="0"/><c:showPercent val="1"/><c:showBubbleSize val="0"/>'
          '<c:showLeaderLines val="0"/></c:dLbls>',
        );
        b.write('${_cat(g)}${_val(g, s)}</c:ser>');
      }
      b.write('<c:firstSliceAng val="0"/>');
      b.write(dona ? '<c:holeSize val="58"/></c:doughnutChart>' : '</c:pieChart>');
    case TipoGrafico.lineas:
      b.write('<c:lineChart><c:grouping val="standard"/><c:varyColors val="0"/>');
      for (var i = 0; i < g.series.length; i++) {
        final s = g.series[i];
        b.write(
          '<c:ser><c:idx val="$i"/><c:order val="$i"/>${_tx(s.nombre)}'
          '<c:spPr><a:ln w="28575" cap="rnd">${_relleno(s.color)}<a:round/></a:ln></c:spPr>'
          '<c:marker><c:symbol val="circle"/><c:size val="6"/><c:spPr>${_relleno(s.color)}'
          '<a:ln w="12700">${_relleno('FFFFFF')}</a:ln></c:spPr></c:marker>'
          '${_cat(g)}${_val(g, s)}<c:smooth val="0"/></c:ser>',
        );
      }
      b.write('${_sinEtiquetas()}<c:marker val="1"/><c:axId val="500001"/><c:axId val="500002"/></c:lineChart>');
      b.write(_ejes(g, horizontal: false, lineas: true));
    case TipoGrafico.barras ||
        TipoGrafico.barrasAgrupadas ||
        TipoGrafico.barrasApiladas ||
        TipoGrafico.barrasHorizontales:
      final horizontal = g.tipo == TipoGrafico.barrasHorizontales;
      final apiladas = g.tipo == TipoGrafico.barrasApiladas && varias;
      b.write(
        '<c:barChart><c:barDir val="${horizontal ? 'bar' : 'col'}"/>'
        '<c:grouping val="${apiladas ? 'stacked' : 'clustered'}"/><c:varyColors val="0"/>',
      );
      for (var i = 0; i < g.series.length; i++) {
        final s = g.series[i];
        b.write(
          '<c:ser><c:idx val="$i"/><c:order val="$i"/>${_tx(s.nombre)}'
          '<c:spPr>${_relleno(s.color)}<a:ln w="9525">${_relleno('FFFFFF')}</a:ln></c:spPr>'
          '<c:invertIfNegative val="0"/>',
        );
        // "Otros" en gris también en Excel.
        for (var k = 0; k < g.categorias.length; k++) {
          if (!varias && esOtros(g.categorias[k])) {
            b.write(
              '<c:dPt><c:idx val="$k"/><c:invertIfNegative val="0"/><c:bubble3D val="0"/>'
              '<c:spPr>${_relleno('9AA39D')}</c:spPr></c:dPt>',
            );
          }
        }
        b.write(
          '${!varias && g.categorias.length <= 15 ? _etiquetasValor(g, posicion: 'outEnd') : ''}'
          '${_cat(g)}${_val(g, s)}</c:ser>',
        );
      }
      b.write(
        '<c:gapWidth val="${varias ? 80 : 55}"/>${apiladas ? '<c:overlap val="100"/>' : (varias ? '<c:overlap val="-8"/>' : '')}'
        '<c:axId val="500001"/><c:axId val="500002"/></c:barChart>',
      );
      b.write(_ejes(g, horizontal: horizontal, lineas: false));
  }

  b.write('<c:spPr><a:noFill/><a:ln><a:noFill/></a:ln></c:spPr></c:plotArea>');
  if (varias || g.tipo.circular) {
    b.write(
      '<c:legend><c:legendPos val="${g.tipo.circular ? 'r' : 'b'}"/><c:overlay val="0"/>${_txPr(tam: 900)}</c:legend>',
    );
  }
  b
    ..write('<c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/></c:chart>')
    ..write('<c:spPr>${_relleno('FFFFFF')}<a:ln w="9525">${_relleno('D2D7D3')}</a:ln></c:spPr>')
    ..write(_txPr())
    ..write(
      '<c:printSettings><c:headerFooter/><c:pageMargins b="0.75" l="0.7" r="0.7" t="0.75" header="0.3" footer="0.3"/>',
    )
    ..write('<c:pageSetup orientation="landscape"/></c:printSettings>')
    ..write('</c:chartSpace>');
  return b.toString();
}

/// XML del dibujo de una hoja: un marco por gráfico; el gráfico i usa la relación rId(i+1).
String xmlDibujoXlsx(List<GraficoXlsx> graficos) {
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
    ..write(
      '<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">',
    );
  for (var i = 0; i < graficos.length; i++) {
    final g = graficos[i];
    b.write(
      '<xdr:twoCellAnchor editAs="oneCell">'
      '<xdr:from><xdr:col>${g.columna}</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>${g.fila}</xdr:row>'
      '<xdr:rowOff>0</xdr:rowOff></xdr:from>'
      '<xdr:to><xdr:col>${g.columna + g.columnas}</xdr:col><xdr:colOff>0</xdr:colOff>'
      '<xdr:row>${g.fila + g.filas}</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to>'
      '<xdr:graphicFrame macro=""><xdr:nvGraphicFramePr><xdr:cNvPr id="${i + 2}" name="Gráfico ${i + 1}"/>'
      '<xdr:cNvGraphicFramePr/></xdr:nvGraphicFramePr>'
      '<xdr:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></xdr:xfrm>'
      '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart">'
      '<c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:id="rId${i + 1}"/>'
      '</a:graphicData></a:graphic></xdr:graphicFrame><xdr:clientData/></xdr:twoCellAnchor>',
    );
  }
  b.write('</xdr:wsDr>');
  return b.toString();
}
