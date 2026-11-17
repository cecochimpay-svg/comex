import 'dart:ui';

import 'package:flutter/material.dart';

import 'arranque.dart';
import 'core/registro/registro.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Todo error no atrapado queda anotado en el registro (comex_registro.txt) para poder diagnosticar.
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    anotar('FlutterError: ${d.exceptionAsString()}\n${d.stack}');
  };
  PlatformDispatcher.instance.onError = (e, s) {
    anotar('Error no atrapado: $e\n$s');
    return true;
  };
  anotar('Inicio de COMEX');
  // Se dibuja enseguida una pantalla de carga; la preparación de la app va adentro de [Arranque].
  runApp(const Arranque());
}
