import 'package:flutter/widgets.dart';

import '../../widgets/revelar_cambio.dart';
import '../preferencias.dart';
import 'paleta.dart';

/// Modo claro / noche de toda la app (queda guardado en el equipo).
///   - Al arrancar: si el usuario nunca eligió, sigue el tema del sistema.
///   - [alternar] cambia de modo, lo guarda y lo revela en círculo desde el botón.
/// Los colores de [Paleta] se leen de nuevo en cada build, así que al cambiar se marca toda la app
/// para redibujar (además de avisar a quien escuche, p. ej. el MaterialApp para rehacer el tema).
class ModoTema extends ChangeNotifier {
  ModoTema(this._prefs, {Brightness? sistema}) {
    Paleta.oscuro = resolver(_prefs.modoOscuro, sistema ?? _brilloSistema);
  }

  final Preferencias _prefs;

  static Brightness get _brilloSistema => WidgetsBinding.instance.platformDispatcher.platformBrightness;

  /// Modo que corresponde: lo elegido, o el del sistema si nunca eligió.
  static bool resolver(bool? elegido, Brightness sistema) => elegido ?? sistema == Brightness.dark;

  bool get oscuro => Paleta.oscuro;

  /// true si el usuario eligió un modo (deja de seguir al sistema).
  bool get elegido => _prefs.modoOscuro != null;

  /// Cambia de modo y lo revela en círculo desde [desde] (centro del botón, en coordenadas de pantalla).
  void alternar({Offset? desde}) => RevelarCambio.ejecutar(() => _aplicar(!Paleta.oscuro, guardar: true), desde: desde);

  /// El sistema cambió de tema: si el usuario nunca eligió, lo sigue.
  void sistemaCambio(Brightness brillo) {
    if (elegido) return;
    final nuevo = brillo == Brightness.dark;
    if (nuevo != Paleta.oscuro) _aplicar(nuevo, guardar: false);
  }

  void _aplicar(bool oscuro, {required bool guardar}) {
    Paleta.oscuro = oscuro;
    if (guardar) _prefs.guardarModoOscuro(oscuro);
    notifyListeners();
    _redibujarTodo();
  }

  static void _redibujarTodo() {
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(marcar);
  }
}
