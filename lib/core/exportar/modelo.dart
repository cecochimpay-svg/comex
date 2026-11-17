import '../db/filas.dart';
import '../formato.dart';
import 'grafico.dart';

export 'grafico.dart';

/// Datos de la exportación común (Excel / PDF). Son objetos simples (sin Flutter) para poder
/// generar el archivo fuera del hilo de la pantalla.

/// Tipo de dato de una columna: define formato, alineación y si se puede totalizar.
enum TipoDato {
  texto,
  entero,

  /// Cantidad (kilos, litros, hectáreas): hasta [ColumnaExport.decimales] decimales, sin ceros sobrantes.
  numero,

  /// Importe en dólares ("U$S 1.234,50").
  dolares,

  /// Importe en pesos ("$ 1.234,50").
  pesos,

  /// Fecha: acepta AAAA-MM-DD (o con hora) y D/M/AAAA; se muestra DD/MM/AAAA.
  fecha,

  /// Porcentaje expresado de 0 a 100 (12.5 -> "12,5 %"; en Excel se guarda 0,125 con formato %).
  porcentaje;

  bool get numerico => this == entero || this == numero || this == dolares || this == pesos || this == porcentaje;
}

class ColumnaExport {
  const ColumnaExport(this.titulo, {this.tipo = TipoDato.texto, this.decimales, this.sumar = false});

  /// Atajo para columnas numéricas que se suman en la fila de totales.
  const ColumnaExport.total(this.titulo, {this.tipo = TipoDato.numero, this.decimales}) : sumar = true;

  final String titulo;
  final TipoDato tipo;

  /// Decimales a mostrar; por defecto 2 en importes y cantidades, 0 en enteros.
  final int? decimales;

  /// Si la tabla no trae [TablaExport.totales], estas columnas se suman automáticamente.
  final bool sumar;

  bool get numerica => tipo.numerico;

  int get decimalesEfectivos => decimales ?? (tipo == TipoDato.entero ? 0 : (tipo == TipoDato.porcentaje ? 1 : 2));
}

class TablaExport {
  const TablaExport({
    required this.titulo,
    required this.columnas,
    required this.filas,
    this.totales,
    this.subtitulo,
    this.graficos = const [],
    this.agruparPor,
    this.columnaEstado,
    this.hojaNueva = true,
  });

  /// PDF: la sección arranca en hoja nueva (false = sigue debajo de la anterior, en la misma hoja).
  final bool hojaNueva;

  /// Nombre de la hoja de Excel / de la sección del PDF.
  final String titulo;
  final List<ColumnaExport> columnas;

  /// Valores crudos (num, String, null…); cada fila con tantas celdas como [columnas].
  final List<List<Object?>> filas;

  /// Fila de totales explícita (null en las celdas vacías). Si es null y alguna columna tiene `sumar`,
  /// se calcula sola; la primera celda dice "TOTALES".
  final List<Object?>? totales;

  /// Línea debajo del título (período, filtros aplicados…).
  final String? subtitulo;

  /// Gráficos de la sección: en el PDF van entre el título y la tabla; en Excel, gráfico nativo a la derecha
  /// de los datos (con [GraficoExport.deTabla] y categorías de texto sin repetir, referencia las celdas).
  final List<GraficoExport> graficos;

  /// Índice de la columna por la que se agrupa: encabezado de grupo + fila de subtotal (columnas con `sumar`)
  /// al final de cada grupo. Los grupos salen en el orden en que aparecen (ordená las filas antes si hace falta).
  /// Excel: subtotales con SUBTOTAL(109, …) y esquema para contraer; el total general no los duplica.
  final int? agruparPor;

  /// Índice de la columna de estado: las filas "ANULADO/A" o "CANCELADO/A" salen tachadas y en gris.
  final int? columnaEstado;

  /// La fila está anulada según [columnaEstado].
  bool anulada(List<Object?> fila) {
    final c = columnaEstado;
    if (c == null || c < 0 || c >= fila.length) return false;
    return RegExp(r'^(ANULAD|CANCELAD)[OA]S?$').hasMatch(txt(fila[c]).trim().toUpperCase());
  }

  /// Filas agrupadas por [agruparPor] (un solo grupo sin clave si no se agrupa).
  List<GrupoExport> get grupos {
    final g = agruparPor;
    if (g == null || g < 0 || g >= columnas.length) return [GrupoExport('', filas, this)];
    final porClave = <String, List<List<Object?>>>{};
    for (final f in filas) {
      final clave = g < f.length ? textoCelda(f[g], columnas[g]).trim() : '';
      porClave.putIfAbsent(clave.isEmpty ? '(sin dato)' : clave, () => []).add(f);
    }
    return [for (final e in porClave.entries) GrupoExport(e.key, e.value, this)];
  }

  /// Totales efectivos (explícitos o calculados) o null si la tabla no lleva.
  List<Object?>? get filaTotales {
    if (totales != null) return totales;
    if (!columnas.any((c) => c.sumar) || filas.isEmpty) return null;
    return [
      for (var i = 0; i < columnas.length; i++)
        if (columnas[i].sumar)
          filas.fold<double>(0, (a, f) => a + (i < f.length && !anulada(f) ? numDe(f[i]) : 0))
        else if (i == 0)
          'TOTALES'
        else
          null,
    ];
  }
}

/// Filas de un grupo de [TablaExport.agruparPor] y su subtotal.
class GrupoExport {
  GrupoExport(this.clave, this.filas, this.tabla);

  final String clave;
  final List<List<Object?>> filas;
  final TablaExport tabla;

  /// Columna del rótulo "Subtotal": la primera que no se suma.
  int get columnaRotulo {
    final i = tabla.columnas.indexWhere((c) => !c.sumar);
    return i < 0 ? 0 : i;
  }

  /// Subtotales de las columnas con `sumar` (null en las demás; filas anuladas no cuentan).
  List<Object?> get subtotales => [
    for (var i = 0; i < tabla.columnas.length; i++)
      if (tabla.columnas[i].sumar)
        filas.fold<double>(0, (a, f) => a + (i < f.length && !tabla.anulada(f) ? numDe(f[i]) : 0))
      else
        null,
  ];

  String get rotuloSubtotal => 'Subtotal ${clave.isEmpty ? '' : '$clave '}(${filas.length})';
}

/// Encabezado común de un informe (lo arma `exportarExcel` / `exportarPdf` desde la pantalla).
class DocumentoExport {
  const DocumentoExport({
    required this.titulo,
    required this.tablas,
    required this.folio,
    required this.emitido,
    required this.operario,
    this.subtitulo,
    this.resumen = const [],
    this.indice = false,
    this.portada = false,
    this.apaisado,
    this.firmas = const [],
    this.graficos = const [],
    this.marcaAgua,
  });

  final String titulo;
  final String? subtitulo;
  final List<TablaExport> tablas;
  final String folio;
  final DateTime emitido;
  final String operario;

  /// Pares (concepto, valor) del resumen: hoja "Portada" en Excel, bloque o portada en PDF.
  final List<(String, String)> resumen;

  /// Excel: agrega una hoja "Índice" con la cantidad de registros de cada hoja.
  final bool indice;

  /// PDF: primera página verde con título, folio y resumen (informe ejecutivo).
  final bool portada;

  /// PDF: null = automático (apaisado si alguna tabla tiene más de 6 columnas).
  final bool? apaisado;

  /// PDF: líneas de firma al final (rol de cada una: "Responsable de galpón", "Administración"…).
  final List<String> firmas;

  /// Gráficos generales del informe (con datos propios): en el PDF van debajo del resumen; en Excel, en una
  /// hoja "Gráficos" (los datos, en la hoja "Datos gráficos").
  final List<GraficoExport> graficos;

  /// Marca de agua en todas las hojas del PDF ("ANULADO", "BORRADOR"…). null = sin marca.
  final String? marcaAgua;

  int get totalFilas => tablas.fold(0, (a, t) => a + t.filas.length);
}

/// Marca institucional (SALVUCCI_CONF del sistema de escritorio).
abstract final class MarcaExport {
  static const empresa = 'SALVUCCI GESTIÓN';
  static const sub = 'AgroSoft J&L · Chimpay, Río Negro';
  static const pie = 'COMEX · CECO S.A.';
  static const verde = 0xFF1E6B4C;
  static const verdeOscuro = 0xFF123F2C;
  static const verdeClaro = 0xFFEAF3EE;
}

/// Folio del informe: PREFIJO-AAMMDD-HHMMSS.
String folioExport(String prefijo, [DateTime? momento]) {
  final d = momento ?? DateTime.now();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '$prefijo-${dos(d.year % 100)}${dos(d.month)}${dos(d.day)}-${dos(d.hour)}${dos(d.minute)}${dos(d.second)}';
}

/// "02/11/2026 15:30" (fecha y hora de emisión, es-AR).
String fechaHoraExport(DateTime d) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
}

/// Fecha de una celda como AAAA-MM-DD (acepta ISO con o sin hora y D/M/AAAA). Si no se reconoce, ''.
String isoDeFecha(Object? v) {
  final s = txt(v);
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  if (iso != null) return '${iso[1]}-${iso[2]!.padLeft(2, '0')}-${iso[3]!.padLeft(2, '0')}';
  final dma = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(s);
  if (dma != null) return '${dma[3]}-${dma[2]!.padLeft(2, '0')}-${dma[1]!.padLeft(2, '0')}';
  return '';
}

/// Texto ya formateado de una celda (PDF y pantalla).
String textoCelda(Object? v, ColumnaExport c) {
  if (v == null || (v is String && v.trim().isEmpty)) return '';
  if (v is String && c.numerica && double.tryParse(v.trim().replaceAll(',', '.')) == null) return v;
  final n = numDe(v);
  return switch (c.tipo) {
    TipoDato.dolares => 'U\$S ${_fijo(n, c.decimalesEfectivos)}',
    TipoDato.pesos => '\$ ${_fijo(n, c.decimalesEfectivos)}',
    TipoDato.entero => fmtNum(n),
    TipoDato.numero => fmtNum(n, decimales: c.decimalesEfectivos),
    TipoDato.porcentaje => '${fmtNum(n, decimales: c.decimalesEfectivos)} %',
    TipoDato.fecha => () {
      final iso = isoDeFecha(v);
      return iso.isEmpty ? txt(v) : fechaCorta(iso);
    }(),
    TipoDato.texto => txt(v),
  };
}

/// Importe con decimales fijos (1.234,50).
String _fijo(double n, int decimales) {
  final s = fmtNum(n, decimales: decimales);
  if (decimales == 0) return s;
  final coma = s.indexOf(',');
  final actuales = coma < 0 ? 0 : s.length - coma - 1;
  return '${coma < 0 ? '$s,' : s}${'0' * (decimales - actuales)}';
}
