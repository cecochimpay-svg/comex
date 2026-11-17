import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// Requiere web/sqlite3.wasm y web/sqflite_sw.js (dart run sqflite_common_ffi_web:setup)
Future<Database> abrirBaseNativa(String nombreArchivo) =>
    databaseFactoryFfiWeb.openDatabase(nombreArchivo);
