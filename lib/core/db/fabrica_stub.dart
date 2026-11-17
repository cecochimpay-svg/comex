import 'package:sqflite_common/sqlite_api.dart';

Future<Database> abrirBaseNativa(String nombreArchivo) =>
    throw UnsupportedError('Esta plataforma no tiene base de datos local.');
