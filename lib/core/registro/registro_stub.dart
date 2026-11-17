/// En web no se escribe a disco.
Future<void> anotar(String linea) async {}

/// Ruta del archivo de registro (null en web).
Future<String?> rutaRegistro() async => null;
