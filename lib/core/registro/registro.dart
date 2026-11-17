/// Registro de arranque y errores en un archivo de texto (en web no hay disco: no hace nada).
library;

export 'registro_stub.dart' if (dart.library.io) 'registro_io.dart';
