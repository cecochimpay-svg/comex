import 'dart:math';
import 'dart:typed_data';

import '../db/filas.dart';
import 'libro_xlsx.dart';
import 'modelo.dart';

/// Arma el .xlsx en memoria con el formato de los Excel de oficina de AgroSoft J&L. Cada hoja de datos:
///   fila 1  título (empresa — informe)      fila 2  subtítulo: alcance, folio, emisión y operario
///   fila 3  totales (SUBTOTAL: cambian al filtrar)
///   fila 4  encabezados                     fila 5… datos como Tabla de Excel (filtros, orden, bandas)
/// Paneles inmovilizados, sin cuadrícula, anchos automáticos (texto largo con ajuste), formatos de número con
/// negativos en rojo, porcentajes y fechas; impresión apaisada ajustada al ancho con el encabezado repetido,
/// área de impresión, encabezado y "Página n de m".
/// Con [TablaExport.agruparPor]: encabezado de grupo, subtotales SUBTOTAL(109, …) y esquema para contraer.
/// Con [TablaExport.graficos]: gráficos nativos a la derecha de los datos.
/// Opcionales: hoja "Portada" (si hay resumen: datos del informe, tarjetas de indicadores y contenido con
/// vínculos), "Índice" (varias hojas, con vínculos), "Gráficos" (gráficos del documento) y "Datos gráficos"
/// (datos de los gráficos que no salen directo de una tabla).
Uint8List generarExcel(DocumentoExport doc) {
  final usados = <String>{};
  String nombreHoja(String titulo) {
    var base = titulo.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    base = base.replaceAll(RegExp(r"^'+|'+$"), '').trim();
    if (base.toLowerCase() == 'history') base = 'History 1';
    var b = base.isEmpty ? 'Hoja' : base.substring(0, min(28, base.length)).trim();
    var nombre = b;
    var n = 2;
    while (usados.contains(nombre.toLowerCase())) {
      b = b.substring(0, min(25, b.length)).trim();
      nombre = '$b ${n++}';
    }
    usados.add(nombre.toLowerCase());
    return nombre;
  }

  // Gráficos resueltos (los vacíos no van).
  final datosTabla = [
    for (final t in doc.tablas)
      [for (final g in t.graficos) (g, datosDeGrafico(g, t))].where((x) => !x.$2.vacio).toList(),
  ];
  final datosDoc = [for (final g in doc.graficos) (g, datosDeGrafico(g))].where((x) => !x.$2.vacio).toList();
  final hayAux = datosDoc.isNotEmpty || datosTabla.any((l) => l.any((x) => !x.$2.filasDirectas));

  // Nombres de hoja (antes de armar nada: los vínculos y los gráficos los necesitan).
  final nPortada = doc.resumen.isNotEmpty ? nombreHoja('Portada') : null;
  final nIndice = doc.indice && doc.tablas.length > 1 ? nombreHoja('Índice') : null;
  final nGraficos = datosDoc.isNotEmpty ? nombreHoja('Gráficos') : null;
  final nTablas = [for (final t in doc.tablas) nombreHoja(t.titulo)];
  final nAux = hayAux ? nombreHoja('Datos gráficos') : null;
  final aux = _DatosAux(nAux ?? '');

  final hojasTablas = <HojaXlsx>[
    for (var i = 0; i < doc.tablas.length; i++)
      _hojaTabla(nTablas[i], doc.tablas[i], doc, _colorDatos, graficos: datosTabla[i], aux: aux),
  ];
  final hojaGraficos = nGraficos == null ? null : _hojaGraficos(nGraficos, doc, datosDoc, aux);

  final contenido = <(String, String, int?)>[
    if (nIndice != null) (nIndice, 'Índice de hojas con la cantidad de registros', null),
    if (nGraficos != null)
      (nGraficos, '${datosDoc.length} gráfico${datosDoc.length == 1 ? '' : 's'} del informe', null),
    for (var i = 0; i < doc.tablas.length; i++)
      (nTablas[i], doc.tablas[i].subtitulo ?? doc.tablas[i].titulo, doc.tablas[i].filas.length),
    if (nAux != null) (nAux, 'Datos de origen de los gráficos', null),
  ];

  final hojas = <HojaXlsx>[
    if (nPortada != null) _portada(nPortada, doc, contenido),
    if (nIndice != null)
      _hojaTabla(
        nIndice,
        _tablaIndice(doc),
        doc,
        _colorAnexo,
        vinculos: [
          for (var i = 0; i < nTablas.length; i++)
            VinculoXlsx('A${_primeraFila + i}', nTablas[i], aviso: 'Ir a la hoja ${nTablas[i]}'),
        ],
      ),
    ?hojaGraficos,
    ...hojasTablas,
    if (nAux != null) aux.hoja(doc),
  ];
  if (hojas.isEmpty) hojas.add(_hojaTabla(nombreHoja(doc.titulo), _vacia(doc.titulo), doc, _colorDatos));
  return generarXlsx(
    hojas,
    creado: doc.emitido,
    propiedades: PropiedadesXlsx(
      titulo: '${MarcaExport.empresa} — ${doc.titulo}',
      asunto: doc.subtitulo ?? doc.titulo,
      palabrasClave: 'COMEX; CECO; AgroSoft J&L; ${doc.folio}',
      descripcion: _lineaEmision(doc),
      modificadoPor: doc.operario,
      categoria: 'Informe',
    ),
  );
}

const _colorDatos = '1E6B4C';
const _colorAnexo = 'B8862A';

/// Fila de los encabezados de cada hoja de tabla (los datos empiezan en la siguiente).
const filaEncabezadoExcel = 4;
const _primeraFila = filaEncabezadoExcel + 1;

TablaExport _vacia(String titulo) =>
    TablaExport(titulo: titulo, columnas: const [ColumnaExport('Sin datos')], filas: const []);

TablaExport _tablaIndice(DocumentoExport doc) => TablaExport(
  titulo: 'Índice del informe',
  subtitulo: doc.titulo,
  columnas: const [
    ColumnaExport('Reporte'),
    ColumnaExport.total('Registros', tipo: TipoDato.entero),
  ],
  filas: [
    for (final t in doc.tablas) [t.titulo, t.filas.length],
  ],
);

String _lineaEmision(DocumentoExport doc) =>
    'Folio ${doc.folio}  ·  Emitido ${fechaHoraExport(doc.emitido)} por ${doc.operario}';

// ───────────────────────────── Estilos ─────────────────────────────

const _titulo = EstiloXlsx(fuente: FuenteXlsx.titulo);
const _subtitulo = EstiloXlsx(fuente: FuenteXlsx.subtitulo);
const _encabezado = EstiloXlsx(
  fuente: FuenteXlsx.encabezado,
  relleno: RellenoXlsx.verde,
  borde: BordeXlsx.encabezado,
  alineacion: AlineacionXlsx.centro,
  ajustar: true,
);

/// Formato de Excel de la columna (negativos en rojo).
String? formatoExcel(ColumnaExport c) {
  final d = c.decimalesEfectivos;
  final decimales = d == 0 ? '' : '.${'0' * d}';
  String conRojo(String f) => '$f;[Red]-$f';
  return switch (c.tipo) {
    TipoDato.dolares => conRojo('"U\$S" #,##0$decimales'),
    TipoDato.pesos => conRojo('"\$" #,##0$decimales'),
    TipoDato.entero => conRojo('#,##0'),
    TipoDato.numero => conRojo('#,##0$decimales'),
    TipoDato.porcentaje => conRojo('0$decimales%'),
    TipoDato.fecha => 'dd/mm/yyyy',
    TipoDato.texto => null,
  };
}

AlineacionXlsx _alineacion(ColumnaExport c) =>
    c.tipo == TipoDato.fecha ? AlineacionXlsx.centro : (c.numerica ? AlineacionXlsx.derecha : AlineacionXlsx.izquierda);

EstiloXlsx _estiloTotal(ColumnaExport? c) => EstiloXlsx(
  fuente: FuenteXlsx.total,
  relleno: RellenoXlsx.verdeClaro,
  borde: BordeXlsx.total,
  formato: c == null ? null : formatoExcel(c),
  alineacion: c == null ? AlineacionXlsx.izquierda : _alineacion(c),
);

EstiloXlsx _estiloSubtotal(ColumnaExport? c) => EstiloXlsx(
  fuente: FuenteXlsx.negrita,
  relleno: RellenoXlsx.tarjeta,
  borde: BordeXlsx.subtotal,
  formato: c == null ? null : formatoExcel(c),
  alineacion: c == null ? AlineacionXlsx.izquierda : _alineacion(c),
);

const _estiloGrupo = EstiloXlsx(fuente: FuenteXlsx.grupo, relleno: RellenoXlsx.grupo, borde: BordeXlsx.grupo);

/// Valor de Excel: números como número (porcentajes como fracción), fechas como fecha, el resto como texto.
Object? _valor(Object? v, ColumnaExport c) {
  if (v == null || (v is String && v.trim().isEmpty)) return null;
  if (c.numerica) {
    if (v is String && double.tryParse(v.trim().replaceAll(',', '.')) == null) return v;
    final n = numDe(v);
    if (c.tipo == TipoDato.porcentaje) return n / 100;
    return c.tipo == TipoDato.entero && n == n.roundToDouble() ? n.round() : n;
  }
  if (c.tipo == TipoDato.fecha) {
    final p = isoDeFecha(v).split('-');
    if (p.length == 3) {
      final (a, m, d) = (int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) return DateTime(a, m, d);
    }
  }
  return txt(v);
}

/// Valor de un total / subtotal ya calculado (porcentaje como fracción).
Object? _valorTotal(Object? v, ColumnaExport c) => v is num && c.tipo == TipoDato.porcentaje ? v / 100 : v;

/// Títulos de columna sin repetir ni vacíos (la Tabla de Excel los exige así).
List<String> _titulosUnicos(List<ColumnaExport> cols) {
  final vistos = <String>{};
  return [
    for (var i = 0; i < cols.length; i++)
      () {
        final base = cols[i].titulo.trim().isEmpty ? 'Columna ${i + 1}' : cols[i].titulo.trim();
        var t = base;
        var n = 2;
        while (!vistos.add(t.toLowerCase())) {
          t = '$base ${n++}';
        }
        return t;
      }(),
  ];
}

// ───────────────────────────── Hojas ─────────────────────────────

/// Ancho máximo de una columna (en caracteres); el texto más largo se ajusta en varias líneas.
const _anchoMaximo = 46;

HojaXlsx _hojaTabla(
  String nombre,
  TablaExport t,
  DocumentoExport doc,
  String color, {
  List<VinculoXlsx> vinculos = const [],
  List<(GraficoExport, DatosGrafico)> graficos = const [],
  _DatosAux? aux,
}) {
  final cols = t.columnas;
  final n = max(1, cols.length);
  final ultimaCol = letraColumna(n - 1);
  final agrupada = t.agruparPor != null && t.agruparPor! >= 0 && t.agruparPor! < cols.length && t.filas.isNotEmpty;
  final grupos = agrupada ? t.grupos : const <GrupoExport>[];
  final hayAnuladas = t.columnaEstado != null && t.filas.any(t.anulada);
  final ultimaFila = _primeraFila + t.filas.length + (agrupada ? grupos.length * 2 : 0) - 1;
  final sub = [
    if (t.subtitulo != null && t.subtitulo!.isNotEmpty) t.subtitulo!,
    _lineaEmision(doc),
    '${t.filas.length} registro${t.filas.length == 1 ? '' : 's'}',
    if (agrupada) '${grupos.length} grupo${grupos.length == 1 ? '' : 's'} por ${cols[t.agruparPor!].titulo}',
  ].join('  ·  ');

  final filas = <FilaXlsx>[
    FilaXlsx(1, [CeldaXlsx('${MarcaExport.empresa}  —  ${t.titulo.toUpperCase()}', _titulo)], alto: 26),
    FilaXlsx(2, [CeldaXlsx(sub, _subtitulo)], alto: 18),
  ];

  // Anchos automáticos: entre 9 y [_anchoMaximo] caracteres según el contenido.
  final largos = <int>[
    for (var c = 0; c < cols.length; c++)
      () {
        var largo = cols[c].titulo.length;
        for (final f in t.filas.take(2000)) {
          if (c < f.length) largo = max(largo, textoCelda(f[c], cols[c]).length);
        }
        return largo;
      }(),
  ];
  final anchos = [for (final l in largos) min(max(l + 3, 9), _anchoMaximo).toDouble()];

  // 3 · totales: SUBTOTAL(109) suma sólo las filas visibles (así acompaña a los filtros) y no cuenta los
  // subtotales de grupo.
  final tot = t.filaTotales;
  if (tot != null && cols.isNotEmpty) {
    final calculados = t.totales == null;
    filas.add(
      FilaXlsx(3, [
        for (var c = 0; c < cols.length; c++)
          () {
            final v = c < tot.length ? tot[c] : null;
            if (v is num) {
              final l = letraColumna(c);
              final valor = calculados && cols[c].sumar && t.filas.isNotEmpty && !hayAnuladas
                  ? FormulaXlsx('SUBTOTAL(109,$l$_primeraFila:$l$ultimaFila)', _valorTotal(v, cols[c]))
                  : _valorTotal(v, cols[c]);
              return CeldaXlsx(valor, _estiloTotal(cols[c]));
            }
            final texto = v == null
                ? null
                : (calculados && v == 'TOTALES' ? (agrupada ? 'Total general' : 'Totales (según filtro)') : txt(v));
            return CeldaXlsx(texto, _estiloTotal(null));
          }(),
      ], alto: 20),
    );
  }

  // 4 · encabezados y 5… datos.
  final titulos = _titulosUnicos(cols);
  filas.add(FilaXlsx(filaEncabezadoExcel, [for (final s in titulos) CeldaXlsx(s, _encabezado)], alto: 32));
  EstiloXlsx estilo(int c, {bool anulada = false}) => EstiloXlsx(
    fuente: anulada ? FuenteXlsx.tachado : FuenteXlsx.normal,
    formato: formatoExcel(cols[c]),
    alineacion: _alineacion(cols[c]),
    ajustar: !cols[c].numerica && largos[c] + 3 > _anchoMaximo,
  );
  final estilos = [for (var c = 0; c < cols.length; c++) estilo(c)];
  final estilosAnulada = [for (var c = 0; c < cols.length; c++) estilo(c, anulada: true)];
  FilaXlsx filaDato(int numero, List<Object?> f, {int nivel = 0}) {
    final anulada = t.anulada(f);
    return FilaXlsx(numero, [
      for (var c = 0; c < cols.length; c++)
        CeldaXlsx(c < f.length ? _valor(f[c], cols[c]) : null, anulada ? estilosAnulada[c] : estilos[c]),
    ], nivel: nivel);
  }

  if (!agrupada) {
    for (var i = 0; i < t.filas.length; i++) {
      filas.add(filaDato(_primeraFila + i, t.filas[i]));
    }
  } else {
    var r = _primeraFila;
    for (final g in grupos) {
      filas.add(
        FilaXlsx(r++, [
          CeldaXlsx(
            '${cols[t.agruparPor!].titulo}: ${g.clave}  ·  ${g.filas.length} registro${g.filas.length == 1 ? '' : 's'}',
            _estiloGrupo,
          ),
          for (var c = 1; c < cols.length; c++) const CeldaXlsx(null, _estiloGrupo),
        ], alto: 20),
      );
      final desde = r;
      for (final f in g.filas) {
        filas.add(filaDato(r++, f, nivel: 1));
      }
      final hasta = r - 1;
      final subt = g.subtotales;
      final rotulo = g.columnaRotulo;
      filas.add(
        FilaXlsx(r++, [
          for (var c = 0; c < cols.length; c++)
            if (cols[c].sumar)
              CeldaXlsx(
                hayAnuladas
                    ? _valorTotal(subt[c], cols[c])
                    : FormulaXlsx(
                        'SUBTOTAL(109,${letraColumna(c)}$desde:${letraColumna(c)}$hasta)',
                        _valorTotal(subt[c], cols[c]),
                      ),
                _estiloSubtotal(cols[c]),
              )
            else
              CeldaXlsx(c == rotulo ? g.rotuloSubtotal : null, _estiloSubtotal(null)),
        ], alto: 18),
      );
    }
  }

  // Gráficos a la derecha de la tabla (una columna de aire), uno debajo del otro.
  final xlsGraficos = <GraficoXlsx>[];
  for (var k = 0; k < graficos.length; k++) {
    final (g, d) = graficos[k];
    final directo = d.filasDirectas && !agrupada;
    final (refCat, refsSeries) = directo
        ? (
            rangoXlsx(
              nombre,
              letraColumna(g.columnaCategoria!),
              _primeraFila,
              letraColumna(g.columnaCategoria!),
              _primeraFila + d.categorias.length - 1,
            ),
            [
              for (final c in g.columnasValores.where((c) => c >= 0 && c < cols.length))
                rangoXlsx(
                  nombre,
                  letraColumna(c),
                  _primeraFila,
                  letraColumna(c),
                  _primeraFila + d.categorias.length - 1,
                ),
            ],
          )
        : aux!.agregar(g.titulo, d);
    xlsGraficos.add(_graficoXlsx(g, d, refCat, refsSeries, columna: n + 1, fila: filaEncabezadoExcel - 1 + k * 22));
  }

  return HojaXlsx(
    nombre: nombre,
    filas: filas,
    anchos: anchos,
    combinadas: n > 1 ? ['A1:${ultimaCol}1', 'A2:${ultimaCol}2'] : const [],
    filasFijas: filaEncabezadoExcel,
    tabla: t.filas.isEmpty || agrupada
        ? null
        : TablaXlsx(filaEncabezado: filaEncabezadoExcel, ultimaFila: ultimaFila, columnas: titulos),
    filaTitulosImpresion: filaEncabezadoExcel,
    apaisado: cols.length > 4,
    pie: '${MarcaExport.empresa} · ${t.titulo} · Folio ${doc.folio}',
    encabezadoImpresion: doc.titulo,
    areaImpresion: 'A1:$ultimaCol${max(ultimaFila, filaEncabezadoExcel)}',
    colorPestana: color,
    vinculos: vinculos,
    graficos: xlsGraficos,
  );
}

GraficoXlsx _graficoXlsx(
  GraficoExport g,
  DatosGrafico d,
  String refCat,
  List<String> refsSeries, {
  required int columna,
  required int fila,
}) {
  final factor = d.formato.tipo == TipoDato.porcentaje ? 0.01 : 1;
  final varias = d.series.length > 1;
  // Valores enteros (litros, kilos): ejes y etiquetas sin decimales.
  final enteros =
      d.formato.tipo != TipoDato.porcentaje &&
      d.series.every((s) => s.valores.every((v) => v == null || v == v.roundToDouble()));
  final formato = enteros ? ColumnaExport('', tipo: d.formato.tipo, decimales: 0) : d.formato;
  return GraficoXlsx(
    tipo: g.tipo,
    titulo: g.subtitulo == null || g.subtitulo!.isEmpty ? g.titulo : '${g.titulo} · ${g.subtitulo}',
    refCategorias: refCat,
    categorias: d.categorias,
    formato: formatoExcel(formato) ?? 'General',
    columna: columna,
    fila: fila,
    coloresPuntos: [
      for (var i = 0; i < d.categorias.length; i++) _hex(colorGrafico(i, otros: esOtros(d.categorias[i]))),
    ],
    series: [
      for (var s = 0; s < d.series.length && s < refsSeries.length; s++)
        SerieXlsx(
          nombre: d.series[s].nombre,
          ref: refsSeries[s],
          valores: [for (final v in d.series[s].valores) v == null ? null : v * factor],
          color: _hex(colorGrafico(varias ? s : 0)),
        ),
    ],
  );
}

String _hex(int argb) => (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

/// Hoja "Datos gráficos": un bloque por gráfico (título, encabezado y una fila por categoría).
class _DatosAux {
  _DatosAux(this.nombre);

  final String nombre;
  final _filas = <FilaXlsx>[];
  var _fila = 4;
  var _series = 1;

  /// Agrega el bloque y devuelve los rangos (categorías, una por serie).
  (String, List<String>) agregar(String titulo, DatosGrafico d) {
    final porcentaje = d.formato.tipo == TipoDato.porcentaje;
    final formato = EstiloXlsx(formato: formatoExcel(d.formato), alineacion: AlineacionXlsx.derecha);
    _filas.add(FilaXlsx(_fila++, [CeldaXlsx(titulo, const EstiloXlsx(fuente: FuenteXlsx.grupo))], alto: 20));
    _filas.add(
      FilaXlsx(_fila++, [
        const CeldaXlsx('Categoría', _encabezado),
        for (final s in d.series) CeldaXlsx(s.nombre, _encabezado),
      ], alto: 22),
    );
    final desde = _fila;
    for (var i = 0; i < d.categorias.length; i++) {
      _filas.add(
        FilaXlsx(_fila++, [
          CeldaXlsx(d.categorias[i], const EstiloXlsx(borde: BordeXlsx.linea)),
          for (final s in d.series)
            CeldaXlsx(
              i < s.valores.length && s.valores[i] != null ? s.valores[i]! * (porcentaje ? 0.01 : 1) : null,
              EstiloXlsx(formato: formato.formato, alineacion: AlineacionXlsx.derecha, borde: BordeXlsx.linea),
            ),
        ]),
      );
    }
    final hasta = _fila - 1;
    _fila++;
    if (d.series.length > _series) _series = d.series.length;
    return (
      rangoXlsx(nombre, 'A', desde, 'A', hasta),
      [
        for (var s = 0; s < d.series.length; s++)
          rangoXlsx(nombre, letraColumna(s + 1), desde, letraColumna(s + 1), hasta),
      ],
    );
  }

  HojaXlsx hoja(DocumentoExport doc) => HojaXlsx(
    nombre: nombre,
    filas: [
      FilaXlsx(1, [CeldaXlsx('${MarcaExport.empresa}  —  DATOS DE LOS GRÁFICOS', _titulo)], alto: 26),
      FilaXlsx(2, [CeldaXlsx('${doc.titulo}  ·  ${_lineaEmision(doc)}', _subtitulo)], alto: 18),
      ..._filas,
    ],
    anchos: [36, for (var s = 0; s < _series; s++) 18],
    apaisado: false,
    pie: '${MarcaExport.empresa} · Datos de los gráficos · Folio ${doc.folio}',
    encabezadoImpresion: doc.titulo,
    colorPestana: _colorAnexo,
  );
}

/// Hoja "Gráficos": los gráficos del documento en dos columnas.
HojaXlsx _hojaGraficos(String nombre, DocumentoExport doc, List<(GraficoExport, DatosGrafico)> datos, _DatosAux aux) {
  final graficos = <GraficoXlsx>[];
  for (var k = 0; k < datos.length; k++) {
    final (g, d) = datos[k];
    final (cat, series) = aux.agregar(g.titulo, d);
    graficos.add(_graficoXlsx(g, d, cat, series, columna: 1 + (k % 2) * 10, fila: 3 + (k ~/ 2) * 22));
  }
  final filas = 3 + ((datos.length + 1) ~/ 2) * 22;
  return HojaXlsx(
    nombre: nombre,
    filas: [
      FilaXlsx(1, [null, CeldaXlsx('${MarcaExport.empresa}  —  ${doc.titulo.toUpperCase()}', _titulo)], alto: 26),
      FilaXlsx(2, [
        null,
        CeldaXlsx(
          [if (doc.subtitulo != null && doc.subtitulo!.isNotEmpty) doc.subtitulo!, _lineaEmision(doc)].join('  ·  '),
          _subtitulo,
        ),
      ], alto: 18),
    ],
    anchos: [2, for (var i = 0; i < 19; i++) 10.5],
    apaisado: true,
    pie: '${MarcaExport.empresa} · Gráficos · Folio ${doc.folio}',
    encabezadoImpresion: doc.titulo,
    areaImpresion: 'A1:T$filas',
    colorPestana: _colorDatos,
    graficos: graficos,
  );
}

/// Portada: marca, datos del informe, tarjetas de indicadores (el resumen) y el contenido del libro con vínculos.
HojaXlsx _portada(String nombre, DocumentoExport doc, List<(String, String, int?)> contenido) {
  const etiqueta = EstiloXlsx(fuente: FuenteXlsx.gris, borde: BordeXlsx.linea);
  const dato = EstiloXlsx(fuente: FuenteXlsx.negrita, borde: BordeXlsx.linea);
  const banda = EstiloXlsx(fuente: FuenteXlsx.banda, relleno: RellenoXlsx.verde, alineacion: AlineacionXlsx.izquierda);
  const tarjetaRotulo = EstiloXlsx(
    fuente: FuenteXlsx.etiqueta,
    relleno: RellenoXlsx.tarjeta,
    borde: BordeXlsx.tarjetaArriba,
    alineacion: AlineacionXlsx.izquierda,
    ajustar: true,
  );
  const tarjetaValor = EstiloXlsx(
    fuente: FuenteXlsx.kpi,
    relleno: RellenoXlsx.tarjeta,
    borde: BordeXlsx.tarjetaAbajo,
    alineacion: AlineacionXlsx.izquierda,
  );
  final combinadas = <String>[];
  final filas = <FilaXlsx>[];
  final vinculos = <VinculoXlsx>[];
  void bandaEn(int r, String texto) {
    filas.add(
      FilaXlsx(r, [null, CeldaXlsx(texto, banda), for (var i = 0; i < 4; i++) const CeldaXlsx(null, banda)], alto: 22),
    );
    combinadas.add('B$r:F$r');
  }

  filas
    ..add(FilaXlsx(2, [null, CeldaXlsx(MarcaExport.empresa, const EstiloXlsx(fuente: FuenteXlsx.portada))], alto: 34))
    ..add(FilaXlsx(3, [null, CeldaXlsx(doc.titulo.toUpperCase(), _titulo)], alto: 24))
    ..add(FilaXlsx(4, [null, CeldaXlsx(MarcaExport.sub, _subtitulo)], alto: 18));
  combinadas.addAll(['B2:F2', 'B3:F3', 'B4:F4']);

  final datos = [
    ('Folio', doc.folio),
    ('Emitido', fechaHoraExport(doc.emitido)),
    ('Generado por', doc.operario),
    if (doc.subtitulo != null && doc.subtitulo!.isNotEmpty) ('Alcance', doc.subtitulo!),
    if (doc.tablas.isNotEmpty) ('Hojas de datos', '${doc.tablas.length} · ${doc.totalFilas} registros'),
  ];
  var r = 6;
  bandaEn(r++, 'DATOS DEL INFORME');
  for (final (k, v) in datos) {
    filas.add(
      FilaXlsx(r, [
        null,
        CeldaXlsx(k, etiqueta),
        const CeldaXlsx(null, etiqueta),
        CeldaXlsx(v, dato),
        const CeldaXlsx(null, dato),
        const CeldaXlsx(null, dato),
      ], alto: 18),
    );
    combinadas.addAll(['B$r:C$r', 'D$r:F$r']);
    r++;
  }

  // Tarjetas de indicadores: tres por fila (B, D, F), rótulo arriba y valor grande abajo.
  r++;
  bandaEn(r++, 'INDICADORES CLAVE');
  r++;
  for (var i = 0; i < doc.resumen.length; i += 3) {
    final grupo = doc.resumen.skip(i).take(3).toList();
    filas.add(
      FilaXlsx(r, [
        null,
        for (var k = 0; k < 3; k++) ...[
          if (k > 0) null,
          k < grupo.length ? CeldaXlsx(grupo[k].$1.toUpperCase(), tarjetaRotulo) : null,
        ],
      ], alto: 20),
    );
    filas.add(
      FilaXlsx(r + 1, [
        null,
        for (var k = 0; k < 3; k++) ...[
          if (k > 0) null,
          k < grupo.length ? CeldaXlsx(grupo[k].$2, tarjetaValor) : null,
        ],
      ], alto: 30),
    );
    filas.add(FilaXlsx(r + 2, const [], alto: 7));
    r += 3;
  }

  if (contenido.isNotEmpty) {
    r++;
    bandaEn(r++, 'CONTENIDO DEL LIBRO');
    const enc = EstiloXlsx(fuente: FuenteXlsx.etiqueta, borde: BordeXlsx.grupo);
    filas.add(
      FilaXlsx(r, [
        null,
        const CeldaXlsx('HOJA', enc),
        const CeldaXlsx(null, enc),
        const CeldaXlsx(
          'REGISTROS',
          EstiloXlsx(fuente: FuenteXlsx.etiqueta, borde: BordeXlsx.grupo, alineacion: AlineacionXlsx.derecha),
        ),
        const CeldaXlsx(null, enc),
        const CeldaXlsx('DETALLE', enc),
      ], alto: 18),
    );
    r++;
    for (final (hoja, detalle, registros) in contenido) {
      filas.add(
        FilaXlsx(r, [
          null,
          CeldaXlsx(hoja, const EstiloXlsx(fuente: FuenteXlsx.vinculo, borde: BordeXlsx.linea)),
          const CeldaXlsx(null, EstiloXlsx(borde: BordeXlsx.linea)),
          CeldaXlsx(
            registros,
            const EstiloXlsx(formato: '#,##0', alineacion: AlineacionXlsx.derecha, borde: BordeXlsx.linea),
          ),
          const CeldaXlsx(null, EstiloXlsx(borde: BordeXlsx.linea)),
          CeldaXlsx(detalle, const EstiloXlsx(fuente: FuenteXlsx.gris, borde: BordeXlsx.linea)),
        ], alto: 18),
      );
      combinadas.add('B$r:C$r');
      vinculos.add(VinculoXlsx('B$r', hoja, aviso: 'Ir a la hoja $hoja'));
      r++;
    }
  }

  return HojaXlsx(
    nombre: nombre,
    filas: filas,
    anchos: const [3, 30, 3, 30, 3, 40, 3],
    combinadas: combinadas,
    apaisado: false,
    pie: '${MarcaExport.pie} · Folio ${doc.folio}',
    encabezadoImpresion: doc.titulo,
    areaImpresion: 'A1:G$r',
    colorPestana: _colorAnexo,
    vinculos: vinculos,
  );
}
