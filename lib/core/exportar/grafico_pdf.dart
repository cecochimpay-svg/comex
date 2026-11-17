import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'modelo.dart';
import 'pdf_comun.dart';

/// Gráficos vectoriales del PDF: tarjeta blanca con título, lienzo (barras, líneas, torta / dona, barras
/// horizontales) y leyenda. Grilla y ejes recesivos, marcas finas con extremos redondeados, etiquetas de
/// valor selectivas y la categoría "Otros" en gris.

const _grilla = PdfColor.fromInt(0xFFE3E7E4);
const _eje = PdfColor.fromInt(0xFFB8C0BA);
const _textoEje = PdfColor.fromInt(0xFF6B766E);
const _tinta = PdfColor.fromInt(0xFF3D4A40);

PdfColor _color(int i, {bool otros = false}) => PdfColor.fromInt(colorGrafico(i, otros: otros));

/// Tarjeta del gráfico [g] con los datos [d], de [alto] puntos.
pw.Widget graficoPdf(BasePdf b, GraficoExport g, DatosGrafico d, {double alto = 200}) {
  final varias = d.series.length > 1;
  final unidad = switch (d.formato.tipo) {
    TipoDato.dolares => 'Valores en U\$S',
    TipoDato.pesos => 'Valores en \$',
    _ => '',
  };
  final leyenda = !g.tipo.circular && varias
      ? pw.Padding(
          padding: const pw.EdgeInsets.only(top: 5),
          child: pw.Wrap(
            spacing: 12,
            runSpacing: 3,
            children: [for (var s = 0; s < d.series.length; s++) _itemLeyenda(b, _color(s), d.series[s].nombre)],
          ),
        )
      : null;
  return pw.Container(
    height: alto,
    padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: ColoresPdf.linea, width: 0.7),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: 2.5, height: 11, color: ColoresPdf.verde, margin: const pw.EdgeInsets.only(right: 5)),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  b.texto(g.titulo, tam: 9, negrita: true, color: ColoresPdf.verdeOscuro, lineas: 1),
                  if (g.subtitulo != null && g.subtitulo!.isNotEmpty)
                    b.texto(g.subtitulo!, tam: 6.8, color: ColoresPdf.gris, lineas: 1),
                ],
              ),
            ),
            if (unidad.isNotEmpty) b.texto(unidad, tam: 6.5, color: ColoresPdf.gris),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Expanded(
          child: g.tipo.circular
              ? pw.Row(
                  children: [
                    pw.Expanded(flex: 5, child: _Lienzo(b, g.tipo, d)),
                    pw.SizedBox(width: 10),
                    pw.Expanded(flex: 6, child: _leyendaCircular(b, d)),
                  ],
                )
              : _Lienzo(b, g.tipo, d),
        ),
        ?leyenda,
      ],
    ),
  );
}

pw.Widget _itemLeyenda(BasePdf b, PdfColor color, String texto) => pw.Row(
  mainAxisSize: pw.MainAxisSize.min,
  children: [
    pw.Container(
      width: 7,
      height: 7,
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(1.5)),
    ),
    pw.SizedBox(width: 4),
    b.texto(texto, tam: 6.8, color: _tinta),
  ],
);

/// Leyenda de torta / dona: color, categoría, valor y porcentaje.
pw.Widget _leyendaCircular(BasePdf b, DatosGrafico d) {
  final valores = d.series.isEmpty ? const <num?>[] : d.series.first.valores;
  final total = valores.fold<double>(0, (a, v) => a + math.max(0, (v ?? 0).toDouble()));
  return pw.Column(
    mainAxisAlignment: pw.MainAxisAlignment.center,
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < d.categorias.length; i++)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.2),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _grilla, width: 0.5)),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 7,
                height: 7,
                decoration: pw.BoxDecoration(
                  color: _color(i, otros: esOtros(d.categorias[i])),
                  borderRadius: pw.BorderRadius.circular(1.5),
                ),
              ),
              pw.SizedBox(width: 5),
              pw.Expanded(child: b.texto(d.categorias[i], tam: 6.8, color: _tinta, lineas: 1)),
              pw.SizedBox(width: 4),
              b.texto(
                i < valores.length && valores[i] != null ? textoCelda(valores[i], d.formato) : '',
                tam: 6.8,
                color: _tinta,
              ),
              pw.SizedBox(
                width: 34,
                child: b.texto(
                  total <= 0 || i >= valores.length
                      ? ''
                      : '${fmtPorcentaje(math.max(0, (valores[i] ?? 0).toDouble()) / total * 100)} %',
                  tam: 6.8,
                  negrita: true,
                  color: ColoresPdf.verdeOscuro,
                  alinear: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// "12,5" (un decimal, sin ceros sobrantes).
String fmtPorcentaje(double p) {
  final s = p.toStringAsFixed(p >= 10 || p == p.roundToDouble() ? 0 : 1);
  return s.replaceAll('.', ',');
}

class _Lienzo extends pw.Widget {
  _Lienzo(this.b, this.tipo, this.d);

  final BasePdf b;
  final TipoGrafico tipo;
  final DatosGrafico d;

  late PdfFont _fuente;
  late PdfFont _negrita;
  late PdfGraphics _c;

  @override
  void layout(pw.Context context, pw.BoxConstraints constraints, {bool parentUsesSize = false}) {
    box = PdfRect(0, 0, constraints.maxWidth, constraints.maxHeight);
  }

  double _ancho(String s, double tam, {bool negrita = false}) =>
      (negrita ? _negrita : _fuente).stringMetrics(s).advanceWidth * tam;

  void _texto(
    String s,
    double x,
    double y,
    double tam, {
    PdfColor color = _textoEje,
    bool negrita = false,
    String alinear = 'izq',
  }) {
    if (s.isEmpty) return;
    final w = _ancho(s, tam, negrita: negrita);
    final dx = switch (alinear) {
      'der' => x - w,
      'centro' => x - w / 2,
      _ => x,
    };
    _c
      ..setFillColor(color)
      ..drawString(negrita ? _negrita : _fuente, tam, s, dx, y);
  }

  /// Recorta con "…" hasta que entre en [maximo].
  String _recortar(String s, double tam, double maximo) {
    if (_ancho(s, tam) <= maximo) return s;
    var t = s;
    while (t.length > 1 && _ancho('$t…', tam) > maximo) {
      t = t.substring(0, t.length - 1);
    }
    return t.length <= 1 ? '' : '${t.trimRight()}…';
  }

  String _seguro(String s) => b.tSeguro(s);

  /// Valor corto del eje (sin "U$S"/"$": la unidad va arriba a la derecha).
  String _corto(num v) => _seguro(
    valorCortoGrafico(
      v,
      ColumnaExport('', tipo: d.formato.tipo == TipoDato.porcentaje ? TipoDato.porcentaje : TipoDato.numero),
    ),
  );

  /// Barra con el extremo de datos redondeado (hacia arriba si [arriba]; hacia la derecha si [horizontal]).
  void _barra(double x, double y, double w, double h, PdfColor color, {bool horizontal = false, bool positivo = true}) {
    if (w <= 0 || h <= 0) return;
    final r = math.min(1.8, math.min(w, h) / 2);
    _c.setFillColor(color);
    const k = 0.5523;
    if (!horizontal) {
      if (positivo) {
        _c
          ..moveTo(x, y)
          ..lineTo(x, y + h - r)
          ..curveTo(x, y + h - r + r * k, x + r - r * k, y + h, x + r, y + h)
          ..lineTo(x + w - r, y + h)
          ..curveTo(x + w - r + r * k, y + h, x + w, y + h - r + r * k, x + w, y + h - r)
          ..lineTo(x + w, y)
          ..closePath();
      } else {
        _c
          ..moveTo(x, y + h)
          ..lineTo(x, y + r)
          ..curveTo(x, y + r - r * k, x + r - r * k, y, x + r, y)
          ..lineTo(x + w - r, y)
          ..curveTo(x + w - r + r * k, y, x + w, y + r - r * k, x + w, y + r)
          ..lineTo(x + w, y + h)
          ..closePath();
      }
    } else {
      _c
        ..moveTo(x, y)
        ..lineTo(x + w - r, y)
        ..curveTo(x + w - r + r * k, y, x + w, y + r - r * k, x + w, y + r)
        ..lineTo(x + w, y + h - r)
        ..curveTo(x + w, y + h - r + r * k, x + w - r + r * k, y + h, x + w - r, y + h)
        ..lineTo(x, y + h)
        ..closePath();
    }
    _c.fillPath();
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    final estilo = pw.Theme.of(context).defaultTextStyle;
    _fuente = estilo.font!.getFont(context);
    _negrita = (estilo.fontBold ?? estilo.font!).getFont(context);
    _c = context.canvas;
    final caja = box!;
    _c.saveContext();
    switch (tipo) {
      case TipoGrafico.torta || TipoGrafico.dona:
        _circular(caja);
      case TipoGrafico.barrasHorizontales:
        _horizontales(caja);
      case TipoGrafico.lineas:
        _cartesiano(caja, lineas: true);
      case TipoGrafico.barras || TipoGrafico.barrasAgrupadas || TipoGrafico.barrasApiladas:
        _cartesiano(caja, lineas: false);
    }
    _c.restoreContext();
  }

  num? _v(int s, int i) => i < d.series[s].valores.length ? d.series[s].valores[i] : null;

  void _cartesiano(PdfRect caja, {required bool lineas}) {
    final n = d.categorias.length;
    final m = d.series.length;
    if (n == 0 || m == 0) return;
    final apiladas = tipo == TipoGrafico.barrasApiladas && m > 1;
    var minimo = 0.0;
    var maximo = 0.0;
    for (var i = 0; i < n; i++) {
      var pos = 0.0;
      var neg = 0.0;
      for (var s = 0; s < m; s++) {
        final v = (_v(s, i) ?? 0).toDouble();
        if (apiladas) {
          if (v >= 0) {
            pos += v;
          } else {
            neg += v;
          }
        } else {
          maximo = math.max(maximo, v);
          minimo = math.min(minimo, v);
        }
      }
      if (apiladas) {
        maximo = math.max(maximo, pos);
        minimo = math.min(minimo, neg);
      }
    }
    if (lineas) {
      minimo = double.infinity;
      maximo = -double.infinity;
      for (var s = 0; s < m; s++) {
        for (final v in d.series[s].valores) {
          if (v == null) continue;
          minimo = math.min(minimo, v.toDouble());
          maximo = math.max(maximo, v.toDouble());
        }
      }
      if (minimo.isInfinite) return;
    }
    final (lo, hi, paso) = escalaGrafico(minimo, maximo, desdeCero: !lineas);
    const tamEje = 6.4;
    final marcas = <double>[for (var v = lo; v <= hi + paso / 1000; v += paso) v];
    final anchoEje = marcas.map((v) => _ancho(_corto(v), tamEje)).fold<double>(0, math.max) + 6;
    const abajo = 13.0;
    final etiquetas = !lineas && m == 1 && n <= 16;
    final arriba = etiquetas ? 9.0 : 4.0;
    final derecha = lineas && m <= 4 ? 4.0 : 2.0;
    final x0 = caja.left + anchoEje;
    final y0 = caja.bottom + abajo;
    final w = caja.width - anchoEje - derecha;
    final h = caja.height - abajo - arriba;
    if (w <= 10 || h <= 10) return;
    double yDe(double v) => y0 + (v - lo) / (hi - lo) * h;

    // Grilla y eje de valores.
    _c.setLineWidth(0.5);
    for (final v in marcas) {
      final y = yDe(v);
      _c
        ..setStrokeColor(v == 0 || v == lo ? _eje : _grilla)
        ..setLineWidth(v == 0 || v == lo ? 0.8 : 0.5)
        ..drawLine(x0, y, x0 + w, y)
        ..strokePath();
      _texto(_corto(v), x0 - 4, y - tamEje * 0.35, tamEje, alinear: 'der');
    }

    // Categorías: una de cada [salto] si no entran.
    final banda = w / n;
    const tamCat = 6.4;
    final anchoMax = n == 0 ? 0.0 : d.categorias.map((c) => _ancho(_seguro(c), tamCat)).fold<double>(0, math.max);
    var salto = 1;
    if (anchoMax > banda - 2) {
      final recortadas = banda >= 34;
      salto = recortadas ? 1 : (anchoMax.clamp(0, 60) / banda).ceil().clamp(1, n);
    }
    for (var i = 0; i < n; i += salto) {
      final cx = x0 + banda * (i + 0.5);
      final t = _recortar(_seguro(d.categorias[i]), tamCat, banda * salto - 3);
      _texto(t, cx, caja.bottom + 3, tamCat, color: _tinta, alinear: 'centro');
    }

    if (lineas) {
      for (var s = 0; s < m; s++) {
        final color = _color(m > 1 ? s : 0);
        _c
          ..setStrokeColor(color)
          ..setLineWidth(1.6)
          ..setLineJoin(PdfLineJoin.round)
          ..setLineCap(PdfLineCap.round);
        var abierto = false;
        for (var i = 0; i < n; i++) {
          final v = _v(s, i);
          if (v == null) {
            abierto = false;
            continue;
          }
          final x = x0 + banda * (i + 0.5);
          final y = yDe(v.toDouble());
          if (abierto) {
            _c.lineTo(x, y);
          } else {
            _c.moveTo(x, y);
            abierto = true;
          }
        }
        _c.strokePath();
        if (n <= 36) {
          for (var i = 0; i < n; i++) {
            final v = _v(s, i);
            if (v == null) continue;
            final x = x0 + banda * (i + 0.5);
            final y = yDe(v.toDouble());
            _c
              ..setFillColor(PdfColors.white)
              ..drawEllipse(x, y, 2.6, 2.6)
              ..fillPath()
              ..setFillColor(color)
              ..drawEllipse(x, y, 1.8, 1.8)
              ..fillPath();
          }
        }
      }
      // Etiqueta selectiva: el máximo de cada serie (con una o dos series).
      if (m == 1) {
        for (var s = 0; s < m; s++) {
          var im = -1;
          for (var i = 0; i < n; i++) {
            final v = _v(s, i);
            if (v != null && (im < 0 || v > _v(s, im)!)) im = i;
          }
          if (im < 0) continue;
          final x = x0 + banda * (im + 0.5);
          final y = yDe(_v(s, im)!.toDouble());
          if (y + 10 < y0 + h + arriba) _texto(_corto(_v(s, im)!), x, y + 4.5, 6.2, color: _tinta, alinear: 'centro');
        }
      }
      return;
    }

    // Barras.
    final grupo = math.min(banda * (m > 1 && !apiladas ? 0.78 : 0.62), m > 1 && !apiladas ? 34.0 * m : 54.0);
    final anchoBarra = apiladas || m == 1 ? grupo : (grupo - (m - 1) * 1.0) / m;
    for (var i = 0; i < n; i++) {
      final otros = esOtros(d.categorias[i]);
      var xb = x0 + banda * i + (banda - grupo) / 2;
      var acumPos = 0.0;
      var acumNeg = 0.0;
      for (var s = 0; s < m; s++) {
        final v = (_v(s, i) ?? 0).toDouble();
        final color = _color(m > 1 ? s : 0, otros: m == 1 && otros);
        if (apiladas) {
          final base = v >= 0 ? acumPos : acumNeg;
          final y1 = yDe(base);
          final y2 = yDe(base + v);
          // Separación de 1 pt entre segmentos (color de fondo).
          final ultimo = s == m - 1 || (v >= 0 ? _restoPos(s, i) == 0 : _restoNeg(s, i) == 0);
          if (v >= 0) {
            _rect(xb, y1, anchoBarra, y2 - y1 - (ultimo ? 0 : 0.8), color, redondo: ultimo);
            acumPos += v;
          } else {
            _rect(
              xb,
              y2 + (ultimo ? 0 : 0.8),
              anchoBarra,
              y1 - y2 - (ultimo ? 0 : 0.8),
              color,
              redondo: ultimo,
              positivo: false,
            );
            acumNeg += v;
          }
        } else {
          final y1 = yDe(0);
          final y2 = yDe(v);
          if (v >= 0) {
            _barra(xb, y1, anchoBarra, y2 - y1, color);
          } else {
            _barra(xb, y2, anchoBarra, y1 - y2, color, positivo: false);
          }
          if (etiquetas && v != 0) {
            final t = _corto(v);
            if (_ancho(t, 6.2) <= banda + 2) {
              _texto(t, xb + anchoBarra / 2, v >= 0 ? y2 + 2.5 : y2 - 7.5, 6.2, color: _tinta, alinear: 'centro');
            }
          }
          xb += anchoBarra + 1.0;
        }
      }
    }
  }

  double _restoPos(int s, int i) {
    var r = 0.0;
    for (var k = s + 1; k < d.series.length; k++) {
      r += math.max(0, (_v(k, i) ?? 0).toDouble());
    }
    return r;
  }

  double _restoNeg(int s, int i) {
    var r = 0.0;
    for (var k = s + 1; k < d.series.length; k++) {
      r += math.min(0, (_v(k, i) ?? 0).toDouble());
    }
    return r;
  }

  void _rect(double x, double y, double w, double h, PdfColor color, {bool redondo = false, bool positivo = true}) {
    if (h <= 0 || w <= 0) return;
    if (redondo) {
      _barra(x, y, w, h, color, positivo: positivo);
    } else {
      _c
        ..setFillColor(color)
        ..drawRect(x, y, w, h)
        ..fillPath();
    }
  }

  void _horizontales(PdfRect caja) {
    final n = d.categorias.length;
    if (n == 0 || d.series.isEmpty) return;
    final m = d.series.length;
    const tam = 6.6;
    final etiquetas = [for (final c in d.categorias) _seguro(c)];
    final anchoCat = math.min(etiquetas.map((c) => _ancho(c, tam)).fold<double>(0, math.max) + 6, caja.width * 0.36);
    var maximo = 0.0;
    var minimo = 0.0;
    for (var s = 0; s < m; s++) {
      for (final v in d.series[s].valores) {
        maximo = math.max(maximo, (v ?? 0).toDouble());
        minimo = math.min(minimo, (v ?? 0).toDouble());
      }
    }
    final textosValor = [
      for (var i = 0; i < n; i++)
        for (var s = 0; s < m; s++) _corto(_v(s, i) ?? 0),
    ];
    final anchoValor = textosValor.map((t) => _ancho(t, 6.3)).fold<double>(0, math.max) + 5;
    final x0 = caja.left + anchoCat;
    final w = caja.width - anchoCat - anchoValor;
    if (w <= 10) return;
    final rango = maximo - minimo == 0 ? 1.0 : maximo - minimo;
    double xDe(double v) => x0 + (v - minimo) / rango * w;
    final fila = caja.height / n;
    final grosor = math.min(fila * (m > 1 ? 0.8 : 0.62), m > 1 ? 18.0 : 12.0);
    final barra = m > 1 ? (grosor - (m - 1)) / m : grosor;
    // Eje en cero.
    _c
      ..setStrokeColor(_eje)
      ..setLineWidth(0.8)
      ..drawLine(xDe(0), caja.bottom, xDe(0), caja.bottom + caja.height)
      ..strokePath();
    for (var i = 0; i < n; i++) {
      final yc = caja.bottom + caja.height - fila * (i + 0.5);
      _texto(_recortar(etiquetas[i], tam, anchoCat - 6), x0 - 5, yc - tam * 0.35, tam, color: _tinta, alinear: 'der');
      var yb = yc + grosor / 2 - barra;
      for (var s = 0; s < m; s++) {
        final v = (_v(s, i) ?? 0).toDouble();
        final color = _color(m > 1 ? s : 0, otros: m == 1 && esOtros(d.categorias[i]));
        if (v >= 0) {
          _barra(xDe(0), yb, xDe(v) - xDe(0), barra, color, horizontal: true);
        } else {
          _c
            ..setFillColor(color)
            ..drawRect(xDe(v), yb, xDe(0) - xDe(v), barra)
            ..fillPath();
        }
        if (barra >= 5) {
          _texto(_corto(v), math.max(xDe(v), xDe(0)) + 3, yb + barra / 2 - 6.3 * 0.35, 6.3, color: _tinta);
        }
        yb -= barra + 1;
      }
    }
  }

  void _circular(PdfRect caja) {
    if (d.series.isEmpty) return;
    final valores = [for (final v in d.series.first.valores) math.max(0, (v ?? 0).toDouble())];
    final total = valores.fold<double>(0, (a, v) => a + v);
    if (total <= 0) return;
    final r = math.min(caja.width, caja.height) / 2 - 2;
    final cx = caja.left + caja.width / 2;
    final cy = caja.bottom + caja.height / 2;
    final dona = tipo == TipoGrafico.dona;
    var angulo = math.pi / 2; // arranca arriba y va en sentido horario
    final medios = <(double, double, int)>[];
    for (var i = 0; i < valores.length; i++) {
      if (valores[i] <= 0) continue;
      final barrido = valores[i] / total * 2 * math.pi;
      final a2 = angulo - barrido;
      final color = _color(i, otros: esOtros(d.categorias[i]));
      _c
        ..setFillColor(color)
        ..setStrokeColor(PdfColors.white)
        ..setLineWidth(1.2);
      if (barrido >= 2 * math.pi - 1e-6) {
        _c.drawEllipse(cx, cy, r, r);
      } else {
        final x1 = cx + r * math.cos(angulo);
        final y1 = cy + r * math.sin(angulo);
        final x2 = cx + r * math.cos(a2);
        final y2 = cy + r * math.sin(a2);
        _c
          ..moveTo(cx, cy)
          ..lineTo(x1, y1)
          ..bezierArc(x1, y1, r, r, x2, y2, large: barrido > math.pi, sweep: false)
          ..closePath();
      }
      _c.fillAndStrokePath();
      medios.add((angulo - barrido / 2, valores[i] / total, i));
      angulo = a2;
    }
    final hueco = dona ? r * 0.58 : 0.0;
    if (dona) {
      _c
        ..setFillColor(PdfColors.white)
        ..drawEllipse(cx, cy, hueco, hueco)
        ..fillPath();
      final t = _seguro(valorCortoGrafico(total, d.formato));
      final tam = math.min(11.0, hueco * 2 * 0.8 / math.max(1, _ancho(t, 1, negrita: true)));
      _texto(t, cx, cy - tam * 0.1, tam, color: ColoresPdf.verdeOscuro, negrita: true, alinear: 'centro');
      _texto('Total', cx, cy - tam * 0.1 - 8.5, 6.4, alinear: 'centro');
    }
    // Porcentaje dentro de las porciones que lo permiten.
    for (final (a, f, _) in medios) {
      if (f < 0.06) continue;
      final rr = dona ? (r + hueco) / 2 : r * 0.64;
      final t = '${fmtPorcentaje(f * 100)}%';
      _texto(
        t,
        cx + rr * math.cos(a),
        cy + rr * math.sin(a) - 2.4,
        6.8,
        color: PdfColors.white,
        negrita: true,
        alinear: 'centro',
      );
    }
  }
}
