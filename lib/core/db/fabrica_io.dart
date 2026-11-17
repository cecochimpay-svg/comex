import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> abrirBaseNativa(String nombreArchivo) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final carpeta = await sqflite.getDatabasesPath();
    return sqflite.openDatabase(p.join(carpeta, nombreArchivo));
  }
  // Escritorio: la base vive en la carpeta de datos de la app (%AppData% en Windows)
  sqfliteFfiInit();
  final carpeta = await getApplicationSupportDirectory();
  await carpeta.create(recursive: true);
  return databaseFactoryFfi.openDatabase(p.join(carpeta.path, nombreArchivo));
}
