import '../db/filas.dart';
import 'modelo.dart';

/// Gráficos de los informes: el modelo ([GraficoExport]) y la preparación de los datos ([datosDeGrafico]),
/// comunes al PDF (dibujo vectorial) y al Excel (gráfico nativo).

enum TipoGrafico {
  /// Columnas verticales (una serie; con varias, lado a lado).
  barras,

  /// Columnas verticales con varias series lado a lado.
  barrasAgrupadas,

  /// Columnas verticales apiladas (composición de un total).
  barrasApiladas,

  /// Barras horizontales: rankings con nombres largos.
  barrasHorizontales,

  /// Evolución en el tiempo.
  lineas,

  /// Torta (participación; usa la primera serie).
  torta,

  /// Dona (como la torta, con el total en el centro).
  dona;

  bool get circular => this == torta || this == dona;
}

class SerieGrafico {
  const SerieGrafico(this.nombre, this.valores);

  final String nombre;

  /// Un valor por categoría (null = sin dato).
  final List<num?> valores;
}

/// Gráfico de un informe (PDF vectorial y gráfico nativo de Excel).
///
/// Con datos propios:
/// ```dart
/// GraficoExport(
///   titulo: 'Litros por mes',
///   tipo: TipoGrafico.lineas,
///   categorias: ['Jul', 'Ago', 'Sep'],
///   series: [SerieGrafico('Gasoil', [1200, 1350, 980]), SerieGrafico('Nafta', [200, 150, 260])],
/// )
/// ```
/// Desde la tabla a la que se adjunta (suma por categoría, ordena de mayor a menor y junta el resto en "Otros"):
/// ```dart
/// GraficoExport.deTabla(titulo: 'Litros por máquina', columnaCategoria: 1, columnasValores: [2])
/// ```
class GraficoExport {
  const GraficoExport({
    required this.titulo,
    this.tipo = TipoGrafico.barras,
    required List<String> this.categorias,
    required List<SerieGrafico> this.series,
    this.tipoValor = TipoDato.numero,
    this.decimales,
    this.subtitulo,
    this.maxCategorias,
    this.ordenar = false,
  }) : columnaCategoria = null,
       columnasValores = const [];

  const GraficoExport.deTabla({
    required this.titulo,
    this.tipo = TipoGrafico.barras,
    required int this.columnaCategoria,
    required this.columnasValores,
    this.tipoValor,
    this.decimales,
    this.subtitulo,
    this.maxCategorias,
    this.ordenar,
  }) : categorias = null,
       series = null;

  final String titulo;

  /// Línea chica debajo del título (unidad, período…).
  final String? subtitulo;
  final TipoGrafico tipo;

  final List<String>? categorias;
  final List<SerieGrafico>? series;

  /// Con [GraficoExport.deTabla]: columna de las categorías y columnas de las series (una serie por columna,
  /// con el título de la columna como nombre). Las filas anuladas no cuentan.
  final int? columnaCategoria;
  final List<int> columnasValores;

  /// Formato de los valores (ejes, etiquetas). null = el de la primera columna de valores.
  final TipoDato? tipoValor;
  final int? decimales;

  /// Máximo de categorías (las demás se suman en "Otros (n)"). null = 6 en torta/dona, 12 en barras,
  /// 15 en barras horizontales, sin límite en líneas. 0 = sin límite.
  final int? maxCategorias;

  /// Ordenar de mayor a menor. null = sí desde la tabla (salvo líneas, que van por fecha / orden de aparición).
  final bool? ordenar;
}

/// Datos listos para dibujar un [GraficoExport].
class DatosGrafico {
  const DatosGrafico({
    required this.categorias,
    required this.series,
    required this.formato,
    this.filasDirectas = false,
  });

  final List<String> categorias;
  final List<SerieGrafico> series;

  /// Para formatear valores con [textoCelda].
  final ColumnaExport formato;

  /// Las categorías son las filas de la tabla en el mismo orden (Excel puede referenciar sus celdas).
  final bool filasDirectas;

  bool get vacio => categorias.isEmpty || series.every((s) => s.valores.every((v) => v == null || v == 0));
}

/// Paleta de series validada para daltonismo (ΔE adyacente ≥ 10) y legible impresa, sin par rojo/verde:
/// verde campo, naranja trigo, azul, magenta, violeta, turquesa, ocre, rosa. "Otros" va en gris.
const paletaGraficos = [0xFF1B7A52, 0xFFD97A12, 0xFF2A78D6, 0xFFB8458A, 0xFF6250D6, 0xFF14A3A0, 0xFFA8701F, 0xFFE87BA4];
const colorOtrosGrafico = 0xFF9AA39D;

/// Color de la serie / porción [i] (la categoría "Otros" siempre gris).
int colorGrafico(int i, {bool otros = false}) => otros ? colorOtrosGrafico : paletaGraficos[i % paletaGraficos.length];

bool esOtros(String categoria) => categoria.startsWith('Otros (');

/// Resuelve los datos de [g] (de la [tabla] si es [GraficoExport.deTabla]).
DatosGrafico datosDeGrafico(GraficoExport g, [TablaExport? tabla]) {
  final cc = g.columnaCategoria;
  List<String> cats;
  List<SerieGrafico> series;
  var directas = false;
  ColumnaExport formato;
  if (cc != null) {
    final t = tabla;
    final cols = [
      for (final i in g.columnasValores)
        if (t != null && i >= 0 && i < t.columnas.length) i,
    ];
    if (t == null || cc < 0 || cc >= t.columnas.length || cols.isEmpty) {
      return const DatosGrafico(categorias: [], series: [], formato: ColumnaExport(''));
    }
    final colCat = t.columnas[cc];
    final base = t.columnas[cols.first];
    formato = ColumnaExport('', tipo: g.tipoValor ?? base.tipo, decimales: g.decimales ?? base.decimales);
    final sumas = <String, List<double>>{};
    final isoDe = <String, String>{};
    for (final f in t.filas) {
      if (t.anulada(f)) continue;
      var c = cc < f.length ? textoCelda(f[cc], colCat).trim() : '';
      if (c.isEmpty) c = '(sin dato)';
      if (colCat.tipo == TipoDato.fecha) isoDe[c] = isoDeFecha(f[cc]);
      final s = sumas.putIfAbsent(c, () => List.filled(cols.length, 0));
      for (var k = 0; k < cols.length; k++) {
        s[k] += cols[k] < f.length ? numDe(f[cols[k]]) : 0;
      }
    }
    cats = sumas.keys.toList();
    if (colCat.tipo == TipoDato.fecha) cats.sort((a, b) => (isoDe[a] ?? a).compareTo(isoDe[b] ?? b));
    series = [
      for (var k = 0; k < cols.length; k++)
        SerieGrafico(t.columnas[cols[k]].titulo, [for (final c in cats) sumas[c]![k]]),
    ];
    directas =
        colCat.tipo == TipoDato.texto &&
        t.agruparPor == null &&
        t.columnaEstado == null &&
        cats.length == t.filas.length;
  } else {
    cats = [...?g.categorias];
    series = [...?g.series];
    formato = ColumnaExport('', tipo: g.tipoValor ?? TipoDato.numero, decimales: g.decimales);
  }
  if (g.tipo.circular && series.length > 1) series = [series.first];

  // Orden de mayor a menor y "Otros".
  final ordenar = g.ordenar ?? (cc != null && g.tipo != TipoGrafico.lineas);
  final limite =
      g.maxCategorias ??
      switch (g.tipo) {
        TipoGrafico.torta || TipoGrafico.dona => 6,
        TipoGrafico.barrasHorizontales => 15,
        TipoGrafico.lineas => 0,
        _ => 12,
      };
  num? v(SerieGrafico s, int i) => i < s.valores.length ? s.valores[i] : null;
  double total(int i) => series.fold<double>(0, (a, s) => a + (v(s, i) ?? 0));
  final idx = [for (var i = 0; i < cats.length; i++) i];
  if (ordenar) idx.sort((a, b) => total(b).compareTo(total(a)));
  final otros = limite > 0 && idx.length > limite;
  if (ordenar || otros) {
    final quedan = otros ? idx.take(limite - 1).toList() : idx;
    final resto = otros ? idx.skip(limite - 1).toList() : const <int>[];
    cats = [for (final i in quedan) cats[i], if (otros) 'Otros (${resto.length})'];
    series = [
      for (final s in series)
        SerieGrafico(s.nombre, [
          for (final i in quedan) v(s, i),
          if (otros) resto.fold<double>(0, (a, i) => a + (v(s, i) ?? 0)),
        ]),
    ];
    var identidad = !otros;
    for (var i = 0; identidad && i < quedan.length; i++) {
      identidad = quedan[i] == i;
    }
    if (!identidad) directas = false;
  }
  return DatosGrafico(categorias: cats, series: series, formato: formato, filasDirectas: directas);
}

/// Valor corto para ejes y etiquetas: "1,2 M", "15,3 mil", "850" (con "U$S"/"$"/"%" según el tipo).
String valorCortoGrafico(num n, ColumnaExport formato) {
  final a = n.abs();
  String cuerpo;
  if (a >= 1e6) {
    cuerpo = '${_corto(n / 1e6)} M';
  } else if (a >= 1e4) {
    cuerpo = '${_corto(n / 1e3)} mil';
  } else {
    cuerpo = _corto(n, decimales: a >= 100 || formato.tipo == TipoDato.entero ? 0 : (a < 10 ? 2 : 1));
  }
  return switch (formato.tipo) {
    TipoDato.dolares => 'U\$S $cuerpo',
    TipoDato.pesos => '\$ $cuerpo',
    TipoDato.porcentaje => '$cuerpo %',
    _ => cuerpo,
  };
}

String _corto(num n, {int decimales = 1}) {
  final s = n.toStringAsFixed(decimales);
  final limpio = s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  final neg = limpio.startsWith('-');
  final partes = (neg ? limpio.substring(1) : limpio).split('.');
  final ent = partes[0];
  final sb = StringBuffer();
  for (var i = 0; i < ent.length; i++) {
    if (i > 0 && (ent.length - i) % 3 == 0) sb.write('.');
    sb.write(ent[i]);
  }
  return '${neg ? '-' : ''}$sb${partes.length > 1 ? ',${partes[1]}' : ''}';
}

/// Escala "linda" para el eje de valores: (mínimo, máximo, paso).
/// [desdeCero] false (líneas): el eje arranca cerca del mínimo para que se vea la variación.
(double, double, double) escalaGrafico(double minimo, double maximo, {int marcas = 5, bool desdeCero = true}) {
  var lo = minimo > 0 && desdeCero ? 0.0 : minimo;
  var hi = maximo < 0 && desdeCero ? 0.0 : maximo;
  if (!desdeCero && hi > lo) {
    final margen = (hi - lo) * 0.15;
    lo = lo >= 0 && lo - margen < 0 ? 0 : lo - margen;
    hi += margen;
  }
  if (hi == lo) hi = lo + 1;
  final crudo = (hi - lo) / marcas;
  final mag = _pot10(crudo);
  final norm = crudo / mag;
  final paso = (norm <= 1 ? 1 : (norm <= 2 ? 2 : (norm <= 2.5 ? 2.5 : (norm <= 5 ? 5 : 10)))) * mag;
  lo = (lo / paso).floorToDouble() * paso;
  hi = (hi / paso).ceilToDouble() * paso;
  return (lo, hi, paso);
}

double _pot10(double x) {
  var p = 1.0;
  if (x <= 0) return 1;
  while (p * 10 <= x) {
    p *= 10;
  }
  while (p > x) {
    p /= 10;
  }
  return p;
}
