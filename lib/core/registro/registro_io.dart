import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _tope = 256 * 1024;
File? _archivo;

Future<File> _abrir() async {
  if (_archivo != null) return _archivo!;
  final base = await getApplicationSupportDirectory();
  await base.create(recursive: true);
  final f = File(p.join(base.path, 'comex_registro.txt'));
  // Si crece demasiado se empieza de nuevo: sólo interesa lo último.
  if (await f.exists() && await f.length() > _tope) await f.writeAsString('');
  return _archivo = f;
}

/// Agrega una línea con fecha y hora. Nunca falla: si no se puede escribir, se ignora.
Future<void> anotar(String linea) async {
  try {
    final f = await _abrir();
    await f.writeAsString('${DateTime.now().toIso8601String()}  $linea\n', mode: FileMode.append, flush: true);
  } catch (_) {}
}

/// Ruta del archivo de registro, para mostrarla al usuario.
Future<String?> rutaRegistro() async {
  try {
    return (await _abrir()).path;
  } catch (_) {
    return null;
  }
}
