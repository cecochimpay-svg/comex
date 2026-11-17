import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'grafico_xlsx.dart';

export 'grafico_xlsx.dart';

/// Escritor de .xlsx propio (el mismo formato que los Excel de oficina de AgroSoft J&L): XML de
/// SpreadsheetML comprimido en zip, sin dependencias pesadas. Permite lo que el paquete `excel` no:
/// paneles inmovilizados, Tabla de Excel con filtros y bandas, fórmulas con valor ya calculado,
/// hoja sin líneas de cuadrícula, color de pestaña, impresión apaisada ajustada al ancho y pie con páginas.

/// Fuentes disponibles (índice = posición en styles.xml).
enum FuenteXlsx {
  normal,
  titulo,
  subtitulo,
  encabezado,
  total,
  gris,
  portada,
  banda,
  valor,
  negrita,

  /// Hipervínculo (azul subrayado).
  vinculo,

  /// Valor grande de una tarjeta de indicador.
  kpi,

  /// Rótulo chico en mayúsculas de una tarjeta.
  etiqueta,

  /// Fila anulada: gris tachado.
  tachado,

  /// Encabezado de grupo.
  grupo,
}

/// Rellenos (los dos primeros de styles.xml son los obligatorios "none" y "gray125").
enum RellenoXlsx { ninguno, verde, verdeClaro, grisClaro, verdeOscuro, tarjeta, grupo }

enum BordeXlsx {
  ninguno,
  encabezado,
  total,
  linea,

  /// Tarjeta de indicador: mitad de arriba / de abajo (acento verde a la izquierda).
  tarjetaArriba,
  tarjetaAbajo,

  /// Encabezado de grupo (línea verde abajo) y subtotal (línea arriba).
  grupo,
  subtotal,
}

enum AlineacionXlsx { general, izquierda, centro, derecha }

class EstiloXlsx {
  const EstiloXlsx({
    this.fuente = FuenteXlsx.normal,
    this.relleno = RellenoXlsx.ninguno,
    this.borde = BordeXlsx.ninguno,
    this.formato,
    this.alineacion = AlineacionXlsx.general,
    this.ajustar = false,
  });

  final FuenteXlsx fuente;
  final RellenoXlsx relleno;
  final BordeXlsx borde;

  /// Código de formato de número de Excel ('#,##0.00', 'dd/mm/yyyy'…); null = General.
  final String? formato;
  final AlineacionXlsx alineacion;

  /// Ajustar texto (varias líneas en la celda).
  final bool ajustar;

  String get _clave => '${fuente.index}|${relleno.index}|${borde.index}|${formato ?? ''}|${alineacion.index}|$ajustar';
}

/// Celda con fórmula. [valor] es el resultado ya calculado (se ve aunque el visor no recalcule).
class FormulaXlsx {
  const FormulaXlsx(this.formula, [this.valor]);

  final String formula;
  final Object? valor;
}

class CeldaXlsx {
  const CeldaXlsx(this.valor, [this.estilo = const EstiloXlsx()]);

  /// String, num, bool, DateTime (fecha), [FormulaXlsx] o null (celda con estilo y sin valor).
  final Object? valor;
  final EstiloXlsx estilo;
}

class FilaXlsx {
  const FilaXlsx(this.numero, this.celdas, {this.alto, this.nivel = 0});

  /// Nivel de esquema (1 = detalle que se contrae bajo su subtotal).
  final int nivel;

  /// Número de fila de Excel (1 = primera).
  final int numero;

  /// Celdas desde la columna A (null = vacía).
  final List<CeldaXlsx?> celdas;
  final double? alto;
}

/// Tabla de Excel (filtros, orden y filas en bandas) sobre un rango con encabezado.
class TablaXlsx {
  const TablaXlsx({required this.filaEncabezado, required this.ultimaFila, required this.columnas});

  final int filaEncabezado;
  final int ultimaFila;

  /// Títulos de las columnas: tienen que coincidir con el texto de la fila de encabezado y no repetirse.
  final List<String> columnas;
}

class HojaXlsx {
  const HojaXlsx({
    required this.nombre,
    required this.filas,
    this.anchos = const [],
    this.combinadas = const [],
    this.filasFijas = 0,
    this.tabla,
    this.filaTitulosImpresion,
    this.apaisado = true,
    this.pie = '',
    this.colorPestana = '1E6B4C',
    this.encabezadoImpresion = '',
    this.areaImpresion,
    this.vinculos = const [],
    this.graficos = const [],
    this.cuadricula = false,
  });

  /// Texto del centro del encabezado impreso (a la izquierda va la empresa y a la derecha la fecha).
  final String encabezadoImpresion;

  /// Rango a imprimir ("A1:F40"); null = toda la hoja.
  final String? areaImpresion;

  /// Hipervínculos internos (a otra hoja del libro).
  final List<VinculoXlsx> vinculos;

  /// Gráficos nativos anclados en la hoja.
  final List<GraficoXlsx> graficos;

  /// Mostrar las líneas de cuadrícula.
  final bool cuadricula;

  /// Nombre de la pestaña (ya validado: hasta 31 caracteres, sin \ / ? * [ ] :, sin repetir).
  final String nombre;
  final List<FilaXlsx> filas;

  /// Ancho de cada columna en caracteres.
  final List<double> anchos;

  /// Rangos combinados ("A1:F1").
  final List<String> combinadas;

  /// Filas inmovilizadas arriba (0 = ninguna).
  final int filasFijas;
  final TablaXlsx? tabla;

  /// Fila que se repite arriba al imprimir (encabezado de la tabla).
  final int? filaTitulosImpresion;
  final bool apaisado;

  /// Texto a la izquierda del pie de página impreso (a la derecha va "Página n de m").
  final String pie;

  /// Color de la pestaña, RRGGBB.
  final String colorPestana;

  int get _ultimaFila => filas.isEmpty ? 1 : filas.map((f) => f.numero).reduce((a, b) => a > b ? a : b);

  int get _columnas {
    var n = anchos.length;
    for (final f in filas) {
      if (f.celdas.length > n) n = f.celdas.length;
    }
    return n < 1 ? 1 : n;
  }
}

/// Hipervínculo de la celda [ref] ("A5") a la celda A1 de la hoja [hoja].
class VinculoXlsx {
  const VinculoXlsx(this.ref, this.hoja, {this.celda = 'A1', this.aviso});

  final String ref;
  final String hoja;
  final String celda;

  /// Texto emergente.
  final String? aviso;
}

/// Propiedades del documento (Archivo > Información).
class PropiedadesXlsx {
  const PropiedadesXlsx({
    this.titulo = '',
    this.autor = 'AgroSoft J&L',
    this.empresa = 'CECO S.A.',
    this.asunto = '',
    this.palabrasClave = '',
    this.descripcion = '',
    this.modificadoPor = '',
    this.categoria = '',
  });

  final String titulo;
  final String autor;
  final String empresa;
  final String asunto;
  final String palabrasClave;
  final String descripcion;
  final String modificadoPor;
  final String categoria;
}

/// A, B, … Z, AA, AB…
String letraColumna(int columna) {
  var n = columna + 1;
  var s = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

/// Arma el .xlsx completo con las [hojas] (la primera queda seleccionada).
/// [propiedades] reemplaza a [titulo] / [autor] si viene.
Uint8List generarXlsx(
  List<HojaXlsx> hojas, {
  String titulo = '',
  String autor = 'AgroSoft J&L',
  DateTime? creado,
  PropiedadesXlsx? propiedades,
}) => _Libro(hojas, propiedades ?? PropiedadesXlsx(titulo: titulo, autor: autor), creado ?? DateTime.now()).generar();

// ───────────────────────────── Implementación ─────────────────────────────

const _fuentes = [
  '<font><sz val="10"/><color rgb="FF1B231D"/><name val="Calibri"/><family val="2"/></font>',
  '<font><b/><sz val="16"/><color rgb="FF123F2C"/><name val="Calibri"/><family val="2"/></font>',
  '<font><i/><sz val="10"/><color rgb="FF5F6B62"/><name val="Calibri"/><family val="2"/></font>',
  '<font><b/><sz val="10"/><color rgb="FFFFFFFF"/><name val="Calibri"/><family val="2"/></font>',
  '<font><b/><sz val="10"/><color rgb="FF123F2C"/><name val="Calibri"/><family val="2"/></font>',
  '<font><sz val="10"/><color rgb="FF5F6B62"/><name val="Calibri"/><family val="2"/></font>',
  '<font><b/><sz val="22"/><color rgb="FF1E6B4C"/><name val="Calibri"/><family val="2"/></font>',
  '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/><family val="2"/></font>',
  '<font><b/><sz val="11"/><color rgb="FF1E6B4C"/><name val="Calibri"/><family val="2"/></font>',
  '<font><b/><sz val="10"/><color rgb="FF1B231D"/><name val="Calibri"/><family val="2"/></font>',
  '<font><u/><sz val="10"/><color rgb="FF1F5FBF"/><name val="Calibri"/><family val="2"/></font>',
  '<font><b/><sz val="17"/><color rgb="FF123F2C"/><name val="Calibri"/><family val="2"/></font>',
  '<font><b/><sz val="8"/><color rgb="FF5F6B62"/><name val="Calibri"/><family val="2"/></font>',
  '<font><strike/><sz val="10"/><color rgb="FF8A938C"/><name val="Calibri"/><family val="2"/></font>',
  '<font><b/><sz val="11"/><color rgb="FF123F2C"/><name val="Calibri"/><family val="2"/></font>',
];

String _relleno(String rgb) =>
    '<fill><patternFill patternType="solid"><fgColor rgb="FF$rgb"/><bgColor indexed="64"/></patternFill></fill>';

final _rellenos = [
  '<fill><patternFill patternType="none"/></fill>',
  '<fill><patternFill patternType="gray125"/></fill>',
  _relleno('1E6B4C'),
  _relleno('E2F0E4'),
  _relleno('F4F6F4'),
  _relleno('123F2C'),
  _relleno('F4F7F5'),
  _relleno('EAF3EE'),
];

String _lado(String lado, [String? estilo, String color = 'D2D7D3']) =>
    estilo == null ? '<$lado/>' : '<$lado style="$estilo"><color rgb="FF$color"/></$lado>';

final _bordes = [
  '<border><left/><right/><top/><bottom/><diagonal/></border>',
  '<border><left style="thin"><color rgb="FF2E8A62"/></left><right style="thin"><color rgb="FF2E8A62"/></right>'
      '<top style="thin"><color rgb="FF2E8A62"/></top><bottom style="thin"><color rgb="FF2E8A62"/></bottom><diagonal/></border>',
  '<border><left/><right/><top style="thin"><color rgb="FF1E6B4C"/></top>'
      '<bottom style="medium"><color rgb="FF1E6B4C"/></bottom><diagonal/></border>',
  '<border><left/><right/><top/><bottom style="hair"><color rgb="FFD2D7D3"/></bottom><diagonal/></border>',
  '<border>${_lado('left', 'thick', '1E6B4C')}${_lado('right', 'thin')}${_lado('top', 'thin')}${_lado('bottom')}<diagonal/></border>',
  '<border>${_lado('left', 'thick', '1E6B4C')}${_lado('right', 'thin')}${_lado('top')}${_lado('bottom', 'thin')}<diagonal/></border>',
  '<border>${_lado('left')}${_lado('right')}${_lado('top')}${_lado('bottom', 'thin', '1E6B4C')}<diagonal/></border>',
  '<border>${_lado('left')}${_lado('right')}${_lado('top', 'thin', '2E8A62')}${_lado('bottom', 'thin')}<diagonal/></border>',
];

/// Formatos de número que Excel ya trae (no hace falta declararlos).
const _formatosIncorporados = {'0': 1, '0.00': 2, '#,##0': 3, '#,##0.00': 4, '@': 49};

class _Libro {
  _Libro(this.hojas, this.propiedades, this.creado);

  final List<HojaXlsx> hojas;
  final PropiedadesXlsx propiedades;
  final DateTime creado;

  final _textos = <String>[];
  final _indiceTexto = <String, int>{};
  final _xfs = <String>['<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'];
  final _indiceXf = <String, int>{const EstiloXlsx()._clave: 0};
  final _formatos = <String, int>{};

  int _texto(String s) => _indiceTexto.putIfAbsent(s, () {
    _textos.add(s);
    return _textos.length - 1;
  });

  int _formato(String? codigo) {
    if (codigo == null) return 0;
    return _formatosIncorporados[codigo] ?? _formatos.putIfAbsent(codigo, () => 164 + _formatos.length);
  }

  int _estilo(EstiloXlsx e) => _indiceXf.putIfAbsent(e._clave, () {
    final fmt = _formato(e.formato);
    final alineacion = switch (e.alineacion) {
      AlineacionXlsx.general => '',
      AlineacionXlsx.izquierda => ' horizontal="left"',
      AlineacionXlsx.centro => ' horizontal="center"',
      AlineacionXlsx.derecha => ' horizontal="right"',
    };
    _xfs.add(
      '<xf numFmtId="$fmt" fontId="${e.fuente.index}" fillId="${e.relleno == RellenoXlsx.ninguno ? 0 : e.relleno.index + 1}" '
      'borderId="${e.borde.index}" xfId="0"${fmt == 0 ? '' : ' applyNumberFormat="1"'} applyFont="1"'
      '${e.relleno == RellenoXlsx.ninguno ? '' : ' applyFill="1"'}${e.borde == BordeXlsx.ninguno ? '' : ' applyBorder="1"'}'
      ' applyAlignment="1"><alignment$alineacion vertical="center"${e.ajustar ? ' wrapText="1"' : ''}/></xf>',
    );
    return _xfs.length - 1;
  });

  static String _xml(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      final valido =
          r == 0x9 ||
          r == 0xA ||
          r == 0xD ||
          (r >= 0x20 && r <= 0xD7FF) ||
          (r >= 0xE000 && r <= 0xFFFD) ||
          r >= 0x10000;
      if (!valido) continue;
      switch (r) {
        case 0x26:
          b.write('&amp;');
        case 0x3C:
          b.write('&lt;');
        case 0x3E:
          b.write('&gt;');
        case 0x22:
          b.write('&quot;');
        default:
          b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  static String _numero(num v) {
    if (v is int) return v.toString();
    if (v.isNaN || v.isInfinite) return '0';
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    return v.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '');
  }

  /// Días desde 30/12/1899 (fecha de Excel).
  static int _serial(DateTime f) => DateTime.utc(f.year, f.month, f.day).difference(DateTime.utc(1899, 12, 30)).inDays;

  String _celda(String ref, CeldaXlsx c) {
    final s = _estilo(c.estilo);
    final v = c.valor;
    final atr = s == 0 ? '' : ' s="$s"';
    if (v == null) return '<c r="$ref"$atr/>';
    if (v is FormulaXlsx) {
      final f = '<f>${_xml(v.formula)}</f>';
      final r = v.valor;
      if (r is num) return '<c r="$ref"$atr>$f<v>${_numero(r)}</v></c>';
      if (r is String) return '<c r="$ref"$atr t="str">$f<v>${_xml(r)}</v></c>';
      return '<c r="$ref"$atr>$f</c>';
    }
    if (v is num) return '<c r="$ref"$atr><v>${_numero(v)}</v></c>';
    if (v is DateTime) return '<c r="$ref"$atr><v>${_serial(v)}</v></c>';
    if (v is bool) return '<c r="$ref"$atr t="b"><v>${v ? 1 : 0}</v></c>';
    final t = v.toString();
    if (t.isEmpty) return '<c r="$ref"$atr/>';
    return '<c r="$ref"$atr t="s"><v>${_texto(t)}</v></c>';
  }

  String _hoja(HojaXlsx h, int indice, bool conTabla) {
    final ultimaCol = letraColumna(h._columnas - 1);
    final ultimaFila = h._ultimaFila;
    final esquema = h.filas.any((f) => f.nivel > 0);
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
      ..write(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
      )
      ..write(
        '<sheetPr><tabColor rgb="FF${h.colorPestana}"/>${esquema ? '<outlinePr summaryBelow="1"/>' : ''}'
        '<pageSetUpPr fitToPage="1"/></sheetPr>',
      )
      ..write('<dimension ref="A1:$ultimaCol$ultimaFila"/>')
      ..write(
        '<sheetViews><sheetView${h.cuadricula ? '' : ' showGridLines="0"'} '
        '${indice == 0 ? 'tabSelected="1" ' : ''}workbookViewId="0">',
      );
    if (h.filasFijas > 0) {
      final primera = h.filasFijas + 1;
      b.write(
        '<pane ySplit="${h.filasFijas}" topLeftCell="A$primera" activePane="bottomLeft" state="frozen"/>'
        '<selection pane="bottomLeft" activeCell="A$primera" sqref="A$primera"/>',
      );
    }
    b
      ..write('</sheetView></sheetViews>')
      ..write('<sheetFormatPr defaultRowHeight="15"${esquema ? ' outlineLevelRow="1"' : ''}/>');
    if (h.anchos.isNotEmpty) {
      b.write('<cols>');
      for (var i = 0; i < h.anchos.length; i++) {
        b.write('<col min="${i + 1}" max="${i + 1}" width="${h.anchos[i]}" customWidth="1"/>');
      }
      b.write('</cols>');
    }
    b.write('<sheetData>');
    final filas = [...h.filas]..sort((a, z) => a.numero.compareTo(z.numero));
    for (final f in filas) {
      b.write(
        '<row r="${f.numero}"${f.alto == null ? '' : ' ht="${f.alto}" customHeight="1"'}'
        '${f.nivel > 0 ? ' outlineLevel="${f.nivel}"' : ''}>',
      );
      for (var c = 0; c < f.celdas.length; c++) {
        final celda = f.celdas[c];
        if (celda != null) b.write(_celda('${letraColumna(c)}${f.numero}', celda));
      }
      b.write('</row>');
    }
    b.write('</sheetData>');
    final t = h.tabla;
    if (t != null && !conTabla && t.ultimaFila > t.filaEncabezado) {
      b.write('<autoFilter ref="A${t.filaEncabezado}:${letraColumna(t.columnas.length - 1)}${t.ultimaFila}"/>');
    }
    if (h.combinadas.isNotEmpty) {
      b.write('<mergeCells count="${h.combinadas.length}">');
      for (final m in h.combinadas) {
        b.write('<mergeCell ref="$m"/>');
      }
      b.write('</mergeCells>');
    }
    if (h.vinculos.isNotEmpty) {
      b.write('<hyperlinks>');
      for (final v in h.vinculos) {
        b.write(
          '<hyperlink ref="${v.ref}" location="${_xml("'${v.hoja.replaceAll("'", "''")}'!${v.celda}")}"'
          '${v.aviso == null ? '' : ' tooltip="${_xml(v.aviso!)}"'} display="${_xml(v.hoja)}"/>',
        );
      }
      b.write('</hyperlinks>');
    }
    final encabezado = h.encabezadoImpresion.isEmpty
        ? ''
        : '<oddHeader>${_xml('&L&8${_amp(propiedades.empresa.toUpperCase())}&C&B${_amp(h.encabezadoImpresion)}&R&8&D')}'
              '</oddHeader>';
    b
      ..write('<printOptions horizontalCentered="1"/>')
      ..write('<pageMargins left="0.4" right="0.4" top="0.6" bottom="0.6" header="0.25" footer="0.3"/>')
      ..write(
        '<pageSetup paperSize="9" orientation="${h.apaisado ? 'landscape' : 'portrait'}" fitToWidth="1" fitToHeight="0"/>',
      )
      ..write(
        '<headerFooter>$encabezado<oddFooter>${_xml('&L&8${_amp(h.pie)}&R&8Página &P de &N')}</oddFooter></headerFooter>',
      );
    // Relaciones de la hoja: rId1 = tabla (si hay), luego el dibujo.
    if (h.graficos.isNotEmpty) b.write('<drawing r:id="rId${conTabla ? 2 : 1}"/>');
    if (conTabla) b.write('<tableParts count="1"><tablePart r:id="rId1"/></tableParts>');
    b.write('</worksheet>');
    return b.toString();
  }

  /// "&" literal en encabezados y pies de impresión.
  static String _amp(String s) => s.replaceAll('&', '&&');

  String _tabla(TablaXlsx t, int id) {
    final ref = 'A${t.filaEncabezado}:${letraColumna(t.columnas.length - 1)}${t.ultimaFila}';
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
      ..write(
        '<table xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" id="$id" '
        'name="Tabla$id" displayName="Tabla$id" ref="$ref">',
      )
      ..write('<autoFilter ref="$ref"/>')
      ..write('<tableColumns count="${t.columnas.length}">');
    for (var i = 0; i < t.columnas.length; i++) {
      b.write('<tableColumn id="${i + 1}" name="${_xml(t.columnas[i])}"/>');
    }
    b.write(
      '</tableColumns>'
      '<tableStyleInfo name="TableStyleLight8" showFirstColumn="0" showLastColumn="0" showRowStripes="1" '
      'showColumnStripes="0"/></table>',
    );
    return b.toString();
  }

  String _estilos() {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
      ..write('<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    if (_formatos.isNotEmpty) {
      b.write('<numFmts count="${_formatos.length}">');
      _formatos.forEach((codigo, id) => b.write('<numFmt numFmtId="$id" formatCode="${_xml(codigo)}"/>'));
      b.write('</numFmts>');
    }
    b
      ..write('<fonts count="${_fuentes.length}">${_fuentes.join()}</fonts>')
      ..write('<fills count="${_rellenos.length}">${_rellenos.join()}</fills>')
      ..write('<borders count="${_bordes.length}">${_bordes.join()}</borders>')
      ..write('<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>')
      ..write('<cellXfs count="${_xfs.length}">${_xfs.join()}</cellXfs>')
      ..write('<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>')
      ..write(
        '<dxfs count="0"/><tableStyles count="0" defaultTableStyle="TableStyleLight8" defaultPivotStyle="PivotStyleLight16"/>',
      )
      ..write('</styleSheet>');
    return b.toString();
  }

  Uint8List generar() {
    final archivo = Archive();
    void agregar(String nombre, String contenido) {
      final bytes = utf8.encode(contenido);
      archivo.addFile(ArchiveFile(nombre, bytes.length, bytes));
    }

    // Primero las hojas: registran los textos compartidos y los estilos que usan.
    final hojasXml = <String>[];
    final tablas = <int, String>{};
    for (var i = 0; i < hojas.length; i++) {
      final t = hojas[i].tabla;
      final conTabla = t != null && t.ultimaFila > t.filaEncabezado;
      if (conTabla) tablas[i] = _tabla(t, tablas.length + 1);
      hojasXml.add(_hoja(hojas[i], i, conTabla));
    }

    // Dibujos (uno por hoja con gráficos) y gráficos (numerados en todo el libro).
    final dibujoDeHoja = <int, int>{};
    final graficosDeDibujo = <int, List<int>>{};
    var totalGraficos = 0;
    for (var i = 0; i < hojas.length; i++) {
      if (hojas[i].graficos.isEmpty) continue;
      final d = dibujoDeHoja.length + 1;
      dibujoDeHoja[i] = d;
      graficosDeDibujo[d] = [for (var k = 0; k < hojas[i].graficos.length; k++) ++totalGraficos];
    }

    const tipoHoja = 'application/vnd.openxmlformats-officedocument.spreadsheetml';
    final tipos = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
      ..write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
      ..write('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
      ..write('<Default Extension="xml" ContentType="application/xml"/>')
      ..write('<Override PartName="/xl/workbook.xml" ContentType="$tipoHoja.sheet.main+xml"/>')
      ..write('<Override PartName="/xl/styles.xml" ContentType="$tipoHoja.styles+xml"/>')
      ..write('<Override PartName="/xl/sharedStrings.xml" ContentType="$tipoHoja.sharedStrings+xml"/>')
      ..write(
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>',
      )
      ..write(
        '<Override PartName="/docProps/app.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>',
      );
    for (var i = 0; i < hojas.length; i++) {
      tipos.write('<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="$tipoHoja.worksheet+xml"/>');
    }
    for (var t = 1; t <= tablas.length; t++) {
      tipos.write('<Override PartName="/xl/tables/table$t.xml" ContentType="$tipoHoja.table+xml"/>');
    }
    for (var d = 1; d <= dibujoDeHoja.length; d++) {
      tipos.write(
        '<Override PartName="/xl/drawings/drawing$d.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>',
      );
    }
    for (var g = 1; g <= totalGraficos; g++) {
      tipos.write(
        '<Override PartName="/xl/charts/chart$g.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"/>',
      );
    }
    tipos.write('</Types>');
    agregar('[Content_Types].xml', tipos.toString());

    const rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    agregar(
      '_rels/.rels',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="$rel/officeDocument" Target="xl/workbook.xml"/>'
          '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" '
          'Target="docProps/core.xml"/>'
          '<Relationship Id="rId3" Type="$rel/extended-properties" Target="docProps/app.xml"/>'
          '</Relationships>',
    );

    final p = propiedades;
    final fecha = '${creado.toUtc().toIso8601String().split('.').first}Z';
    String dc(String etiqueta, String valor) => valor.isEmpty ? '' : '<$etiqueta>${_xml(valor)}</$etiqueta>';
    agregar(
      'docProps/core.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
          '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
          'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
          'xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
          '${dc('dc:title', p.titulo)}${dc('dc:subject', p.asunto)}${dc('dc:creator', p.autor)}'
          '${dc('cp:keywords', p.palabrasClave)}${dc('dc:description', p.descripcion)}'
          '${dc('cp:lastModifiedBy', p.modificadoPor)}${dc('cp:category', p.categoria)}'
          '<dcterms:created xsi:type="dcterms:W3CDTF">$fecha</dcterms:created>'
          '<dcterms:modified xsi:type="dcterms:W3CDTF">$fecha</dcterms:modified>'
          '</cp:coreProperties>',
    );
    final nombres = StringBuffer();
    for (final h in hojas) {
      nombres.write('<vt:lpstr>${_xml(h.nombre)}</vt:lpstr>');
    }
    agregar(
      'docProps/app.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
          '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
          'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
          '<Application>AgroSoft J&amp;L</Application><DocSecurity>0</DocSecurity><ScaleCrop>false</ScaleCrop>'
          '<HeadingPairs><vt:vector size="2" baseType="variant"><vt:variant><vt:lpstr>Hojas de cálculo</vt:lpstr>'
          '</vt:variant><vt:variant><vt:i4>${hojas.length}</vt:i4></vt:variant></vt:vector></HeadingPairs>'
          '<TitlesOfParts><vt:vector size="${hojas.length}" baseType="lpstr">$nombres</vt:vector></TitlesOfParts>'
          '${p.empresa.isEmpty ? '' : '<Company>${_xml(p.empresa)}</Company>'}'
          '<LinksUpToDate>false</LinksUpToDate><SharedDoc>false</SharedDoc><HyperlinksChanged>false</HyperlinksChanged>'
          '<AppVersion>16.0300</AppVersion></Properties>',
    );

    final libro = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
      ..write('<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="$rel">')
      ..write('<workbookPr/><bookViews><workbookView activeTab="0"/></bookViews><sheets>');
    for (var i = 0; i < hojas.length; i++) {
      libro.write('<sheet name="${_xml(hojas[i].nombre)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
    }
    libro.write('</sheets>');
    String hojaRef(int i) => _xml("'${hojas[i].nombre.replaceAll("'", "''")}'");
    // Excel exige los nombres definidos ordenados por nombre: primero las áreas de impresión, después los títulos.
    final definidos = [
      for (var i = 0; i < hojas.length; i++)
        if (hojas[i].areaImpresion case final a?)
          '<definedName name="_xlnm.Print_Area" localSheetId="$i">${hojaRef(i)}!${_absoluto(a)}</definedName>',
      for (var i = 0; i < hojas.length; i++)
        if (hojas[i].filaTitulosImpresion case final f?)
          '<definedName name="_xlnm.Print_Titles" localSheetId="$i">${hojaRef(i)}!\$$f:\$$f</definedName>',
    ];
    if (definidos.isNotEmpty) libro.write('<definedNames>${definidos.join()}</definedNames>');
    libro.write('<calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>');
    agregar('xl/workbook.xml', libro.toString());

    final rels = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
      ..write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (var i = 0; i < hojas.length; i++) {
      rels.write('<Relationship Id="rId${i + 1}" Type="$rel/worksheet" Target="worksheets/sheet${i + 1}.xml"/>');
    }
    rels
      ..write('<Relationship Id="rId${hojas.length + 1}" Type="$rel/styles" Target="styles.xml"/>')
      ..write('<Relationship Id="rId${hojas.length + 2}" Type="$rel/sharedStrings" Target="sharedStrings.xml"/>')
      ..write('</Relationships>');
    agregar('xl/_rels/workbook.xml.rels', rels.toString());

    const encabezadoRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">';
    var t = 0;
    for (var i = 0; i < hojas.length; i++) {
      agregar('xl/worksheets/sheet${i + 1}.xml', hojasXml[i]);
      final relsHoja = <String>[];
      if (tablas.containsKey(i)) {
        t++;
        agregar('xl/tables/table$t.xml', tablas[i]!);
        relsHoja.add('<Relationship Id="rId1" Type="$rel/table" Target="../tables/table$t.xml"/>');
      }
      if (dibujoDeHoja[i] case final d?) {
        relsHoja.add(
          '<Relationship Id="rId${relsHoja.length + 1}" Type="$rel/drawing" Target="../drawings/drawing$d.xml"/>',
        );
        final numeros = graficosDeDibujo[d]!;
        agregar('xl/drawings/drawing$d.xml', xmlDibujoXlsx(hojas[i].graficos));
        agregar(
          'xl/drawings/_rels/drawing$d.xml.rels',
          '$encabezadoRels${[for (var k = 0; k < numeros.length; k++) '<Relationship Id="rId${k + 1}" Type="$rel/chart" Target="../charts/chart${numeros[k]}.xml"/>'].join()}'
              '</Relationships>',
        );
        for (var k = 0; k < numeros.length; k++) {
          agregar('xl/charts/chart${numeros[k]}.xml', xmlGraficoXlsx(hojas[i].graficos[k]));
        }
      }
      if (relsHoja.isNotEmpty) {
        agregar('xl/worksheets/_rels/sheet${i + 1}.xml.rels', '$encabezadoRels${relsHoja.join()}</Relationships>');
      }
    }
    agregar('xl/styles.xml', _estilos());

    final compartidos = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
      ..write(
        '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'count="${_textos.length}" uniqueCount="${_textos.length}">',
      );
    for (final s in _textos) {
      compartidos.write('<si><t xml:space="preserve">${_xml(s)}</t></si>');
    }
    compartidos.write('</sst>');
    agregar('xl/sharedStrings.xml', compartidos.toString());

    final zip = ZipEncoder().encode(archivo);
    if (zip == null) throw StateError('No se pudo comprimir el Excel.');
    return Uint8List.fromList(zip);
  }

  /// "A1:F40" -> "$A$1:$F$40".
  static String _absoluto(String rango) => rango
      .split(':')
      .map((r) => r.replaceAllMapped(RegExp(r'^([A-Z]+)(\d+)$'), (m) => '\$${m[1]}\$${m[2]}'))
      .join(':');
}
