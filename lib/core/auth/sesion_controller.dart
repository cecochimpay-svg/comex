import 'package:flutter/foundation.dart';

import '../nav/catalogo.dart';
import 'auth_servicio.dart';
import 'sesion.dart';

/// Estado de la sesión para la pantalla. El enrutador escucha sus cambios
/// (login -> menú principal, logout -> login).
class SesionController extends ChangeNotifier {
  SesionController(this._auth);

  final AuthServicio _auth;
  Sesion? _sesion;

  Sesion? get actual => _actual;

  set _actual(Sesion? s) {
    _sesion = s;
    sesionVisible = s; // el menú se arma con los permisos del usuario
  }

  Sesion? get _actual => _sesion;

  Future<void> restaurar() async {
    try {
      _actual = await _auth.sesionActual();
    } catch (_) {
      _actual = null;
    }
  }

  Future<ResultadoLogin> iniciarSesion(String usuario, String clave) async {
    final r = await _auth.login(usuario, clave);
    if (r.ok) {
      _actual = r.sesion;
      notifyListeners();
    }
    return r;
  }

  Future<void> cerrarSesion() async {
    await _auth.logout();
    _actual = null;
    notifyListeners();
  }
}
