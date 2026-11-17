import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../widgets/avisos.dart';
import '../auth/sesion_controller.dart';
import '../formato.dart';
import 'excel_informe.dart';
import 'modelo.dart';
import 'pdf_informe.dart';
import 'remito_pdf.dart';

export 'package:file_saver/file_saver.dart' show MimeType;

export 'excel_informe.dart' show generarExcel;
export 'modelo.dart';
export 'pdf_informe.dart' show RecursosPdf, generarPdf;
export 'remito_pdf.dart' show RemitoExport, TarjetaRemito, generarRemitoPdf;

/// Exportación común a Excel y PDF para todas las pantallas.
///
/// ```dart
/// final tabla = TablaExport(
///   titulo: 'Despachos de combustible',
///   subtitulo: 'Período: 01/10/2026 a 31/10/2026',
///   columnas: const [
///     ColumnaExport('Fecha', tipo: TipoDato.fecha),
///     ColumnaExport('Máquina'),
///     ColumnaExport.total('Litros'),
///     ColumnaExport.total('Total U\$S', tipo: TipoDato.dolares),
///   ],
///   filas: [for (final f in filas) [f['fecha'], f['maquina'], f['cantidad'], f['total_dolar']]],
/// );
/// await exportarExcel(context, nombreArchivo: 'Despachos_combustible', hojas: [tabla]);
/// await exportarPdf(context, nombreArchivo: 'Despachos_combustible', titulo: 'Despachos de combustible', tablas: [tabla]);
/// ```
/// Ambas devuelven true si el archivo se guardó (false si se canceló o falló; el aviso ya se mostró).
/// En la PC, el archivo guardado se abre con el programa predeterminado (Excel, visor de PDF).

/// Genera el .xlsx (una hoja por tabla) y lo ofrece para guardar.
/// [resumen] agrega una hoja "Portada" y [indice] una hoja "Índice" (con varias hojas).
Future<bool> exportarExcel(
  BuildContext context, {
  required String nombreArchivo,
  required List<TablaExport> hojas,
  String? titulo,
  String? subtitulo,
  List<(String, String)> resumen = const [],
  bool indice = false,
  String prefijoFolio = 'XLS',
  List<GraficoExport> graficos = const [],
}) async {
  final doc = DocumentoExport(
    titulo: titulo ?? (hojas.isEmpty ? nombreArchivo : hojas.first.titulo),
    subtitulo: subtitulo,
    tablas: hojas,
    folio: folioExport(prefijoFolio),
    emitido: DateTime.now(),
    operario: operarioExport(context),
    resumen: resumen,
    indice: indice,
    graficos: graficos,
  );
  return _exportar(
    context,
    tipo: 'Excel',
    nombre: nombreArchivo,
    extension: 'xlsx',
    mime: MimeType.microsoftExcel,
    mensaje: _mensajeFilas('Excel', doc),
    generar: () => compute(generarExcel, doc),
  );
}

String _mensajeFilas(String tipo, DocumentoExport doc) {
  final filas = doc.totalFilas;
  return '$tipo generado: ${fmtNum(filas)} fila${filas == 1 ? '' : 's'}.';
}

/// Genera el PDF (una sección por tabla, encabezado y pie del sistema) y lo ofrece para guardar.
/// [apaisado] null = automático (apaisado con más de 6 columnas). [portada] = primera página verde con
/// el [resumen]; sin portada, el resumen va en un bloque arriba de la primera tabla. [firmas]: líneas de firma
/// al final (rol de cada una).
Future<bool> exportarPdf(
  BuildContext context, {
  required String nombreArchivo,
  required String titulo,
  required List<TablaExport> tablas,
  String? subtitulo,
  List<(String, String)> resumen = const [],
  bool? apaisado,
  bool portada = false,
  String prefijoFolio = 'PDF',
  List<String> firmas = const [],
  List<GraficoExport> graficos = const [],
  String? marcaAgua,
}) async {
  final doc = DocumentoExport(
    graficos: graficos,
    marcaAgua: marcaAgua,
    titulo: titulo,
    subtitulo: subtitulo,
    tablas: tablas,
    folio: folioExport(prefijoFolio),
    emitido: DateTime.now(),
    operario: operarioExport(context),
    resumen: resumen,
    portada: portada,
    apaisado: apaisado,
    firmas: firmas,
  );
  return _exportar(
    context,
    tipo: 'PDF',
    nombre: nombreArchivo,
    extension: 'pdf',
    mime: MimeType.pdf,
    mensaje: _mensajeFilas('PDF', doc),
    generar: () async {
      final recursos = await cargarRecursosPdf();
      return compute(_pdfAislado, (doc, recursos));
    },
  );
}

Future<Uint8List> _pdfAislado((DocumentoExport, RecursosPdf) p) => generarPdf(p.$1, recursos: p.$2);

/// Genera el remito (ORIGINAL y DUPLICADO en una hoja A4) y lo ofrece para guardar; en la PC lo abre para
/// imprimirlo. El nombre del archivo no lleva la fecha del día (ya la lleva el remito).
Future<bool> exportarRemitoPdf(BuildContext context, {required String nombreArchivo, required RemitoExport remito}) =>
    _exportar(
      context,
      tipo: 'PDF',
      nombre: nombreArchivo,
      conFecha: false,
      extension: 'pdf',
      mime: MimeType.pdf,
      mensaje: 'Remito Nº ${remito.numero} generado.',
      generar: () async {
        final recursos = await cargarRecursosPdf();
        return compute(_remitoAislado, (remito, recursos));
      },
    );

Future<Uint8List> _remitoAislado((RemitoExport, RecursosPdf) p) => generarRemitoPdf(p.$1, recursos: p.$2);

/// Guarda (y en la PC abre) un archivo ya generado por el módulo: diálogo "Guardar como" / descarga en la web,
/// aviso con [mensaje] y la ruta. [conFecha]: agrega la fecha del día al nombre. Devuelve true si se guardó.
///
/// ```dart
/// final bytes = await miPdfPropio();
/// await guardarDocumento(context, nombreArchivo: 'Receta_OT_123', bytes: bytes, extension: 'pdf',
///     mime: MimeType.pdf, mensaje: 'Receta generada.', conFecha: false);
/// ```
Future<bool> guardarDocumento(
  BuildContext context, {
  required String nombreArchivo,
  required Uint8List bytes,
  required String extension,
  MimeType mime = MimeType.other,
  String? mensaje,
  bool conFecha = true,
}) => _exportar(
  context,
  tipo: extension.toUpperCase(),
  nombre: nombreArchivo,
  extension: extension,
  mime: mime,
  mensaje: mensaje ?? 'Archivo generado.',
  conFecha: conFecha,
  generar: () async => bytes,
);

/// Logos y fuentes del PDF desde los assets (si falta alguno, el PDF sale igual). Se leen una sola vez.
Future<RecursosPdf> cargarRecursosPdf() async => _recursos ??= await _leerRecursosPdf();

RecursosPdf? _recursos;

Future<RecursosPdf> _leerRecursosPdf() async {
  Future<Uint8List?> leer(String ruta) async {
    try {
      return (await rootBundle.load(ruta)).buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  return RecursosPdf(
    logo: await _achicar(await leer('assets/icono/icono.png'), 160),
    fuente: await leer('assets/fuentes/NotoSans-Regular.ttf'),
    fuenteNegrita: await leer('assets/fuentes/NotoSans-Bold.ttf'),
    logoSistema: await _achicar(await leer('assets/logo_agrosoft.png'), 96),
    fuenteSimbolos: await leer('assets/fuentes/DejaVuSans-Simbolos.ttf'),
  );
}

/// Los logos originales son de 1024 px: se achican para que cada PDF no cargue con 1 MB de imagen.
Future<Uint8List?> _achicar(Uint8List? png, int ancho) async {
  if (png == null) return null;
  try {
    final codec = await ui.instantiateImageCodec(png, targetWidth: ancho, targetHeight: ancho);
    final imagen = (await codec.getNextFrame()).image;
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();
    return datos?.buffer.asUint8List() ?? png;
  } catch (_) {
    return png;
  }
}

/// Nombre del usuario logueado (o "—" si no hay sesión).
String operarioExport(BuildContext context) {
  try {
    final n = context.read<SesionController>().actual?.nombre.trim() ?? '';
    return n.isEmpty ? '—' : n.toUpperCase();
  } catch (_) {
    return '—';
  }
}

/// Guarda los bytes: diálogo "Guardar como" en Windows / Android / iOS, descarga en la web.
/// Devuelve la ruta (o el nombre en la web) o null si se canceló.
typedef GuardadorArchivo = Future<String?> Function({
  required String nombre,
  required String extension,
  required Uint8List bytes,
  required MimeType mime,
});

Future<String?> _guardarConDialogo({
  required String nombre,
  required String extension,
  required Uint8List bytes,
  required MimeType mime,
}) async {
  if (kIsWeb) {
    return FileSaver.instance.saveFile(name: nombre, bytes: bytes, fileExtension: extension, mimeType: mime);
  }
  return FileSaver.instance.saveAs(
    name: nombre,
    bytes: bytes,
    fileExtension: extension,
    mimeType: mime,
    dialogTitle: 'Guardar $nombre.$extension',
  );
}

/// Reemplazable en los tests para no abrir el diálogo del sistema.
@visibleForTesting
GuardadorArchivo guardarArchivo = _guardarConDialogo;

/// Abre el archivo guardado con el programa predeterminado (sólo en la PC y si el archivo existe).
@visibleForTesting
Future<void> Function(String ruta) abrirArchivo = _abrirConSistema;

Future<void> _abrirConSistema(String ruta) async {
  if (kIsWeb || !(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
  try {
    if (!File(ruta).existsSync()) return;
    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', ruta]);
    } else {
      await Process.start(Platform.isMacOS ? 'open' : 'xdg-open', [ruta]);
    }
  } catch (_) {
    // Sin programa asociado: el archivo igual quedó guardado y el aviso dice dónde.
  }
}

/// Nombre de archivo seguro con la fecha del día: "COMEX_vuelos_2026-11-02".
String nombreConFecha(String base, [DateTime? d]) {
  final f = d ?? DateTime.now();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${nombreArchivoSeguro(base)}_${f.year}-${dos(f.month)}-${dos(f.day)}';
}

/// Sin caracteres prohibidos en Windows ni espacios: "Remito 12/A" -> "Remito_12_A".
String nombreArchivoSeguro(String base) => base.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');

Future<bool> _exportar(
  BuildContext context, {
  required String tipo,
  required String nombre,
  required String extension,
  required MimeType mime,
  required String mensaje,
  required Future<Uint8List> Function() generar,
  bool conFecha = true,
}) async {
  try {
    final bytes = await generar();
    final base = conFecha ? nombreConFecha(nombre) : nombreArchivoSeguro(nombre);
    final ruta = await guardarArchivo(nombre: base, extension: extension, bytes: bytes, mime: mime);
    if (ruta == null || ruta.isEmpty) return false;
    if (context.mounted) mostrarAviso(context, '$mensaje${kIsWeb ? '' : '\n$ruta'}');
    if (!kIsWeb) await abrirArchivo(ruta);
    return true;
  } catch (e) {
    if (context.mounted) mostrarAviso(context, 'No se pudo exportar a $tipo: $e', tipo: TipoAviso.error);
    return false;
  }
}
