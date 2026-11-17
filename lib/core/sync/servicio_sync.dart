import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../datos/datos_nube.dart';
import '../preferencias.dart';
import '../red.dart';

/// Pide la contraseña de la nube cuando no hay sesión de Supabase Auth (null = cancelado).
typedef PedirClaveNube = Future<({String correo, String clave})?> Function(String correo, String mensajeError);

enum TipoResultadoSync { exito, aviso, error }

class ResultadoSync {
  const ResultadoSync(this.tipo, this.mensaje);
  final TipoResultadoSync tipo;
  final String mensaje;
}

/// Columna clave de cada tabla de Supabase que COMEX modifica (para subir los cambios pendientes).
/// Las pantallas registran las suyas con [ServicioSync.registrarTabla].
final clavesTablas = <String, String>{
  'logistitcas_temporada': 'registro',
  // Programa de trabajo: un renglón por calibre; las altas sin conexión no tienen id (se insertan).
  'comex_programa_trabajo': 'id',
  // Proyección de 11 días: una fila por fecha y usuario (mismo onConflict que la versión Electron).
  'comex_proyeccion_dias': 'fecha,usuario',
};

/// Sincronización COMEX: sube los cambios hechos sin conexión y avisa a las pantallas para que relean.
/// (Las pantallas leen siempre de la nube cuando hay red, así que no hace falta una bajada completa.)
class ServicioSync extends ChangeNotifier {
  ServicioSync(this._nube, this._prefs) {
    Future.microtask(actualizarPendientes);
  }

  final SupabaseClient _nube;
  final Preferencias _prefs;

  bool _sincronizando = false;
  int _pendientes = 0;
  int _version = 0;

  bool get sincronizando => _sincronizando;

  /// Cambios hechos en este equipo que todavía no subieron.
  int get pendientes => _pendientes;

  /// Cambia en cada sincronización: las pantallas la escuchan para volver a leer.
  int get version => _version;

  static void registrarTabla(String tabla, String clave) => clavesTablas[tabla] = clave;

  Future<void> actualizarPendientes() async {
    try {
      final n = await DatosNube.pendientes();
      if (n != _pendientes) {
        _pendientes = n;
        notifyListeners();
      }
    } catch (_) {
      // base todavía cerrada (tests / arranque)
    }
  }

  Future<ResultadoSync> sincronizarTodo({required String correoSesion, required PedirClaveNube pedirClave}) async {
    if (_sincronizando) return const ResultadoSync(TipoResultadoSync.aviso, 'Ya hay una sincronización en curso.');

    try {
      if (!await _asegurarSesionNube(correoSesion, pedirClave)) {
        return const ResultadoSync(TipoResultadoSync.error, 'Sincronización cancelada: falta iniciar sesión en la nube.');
      }
    } catch (e) {
      return esErrorDeRed(e)
          ? _sinConexion
          : ResultadoSync(TipoResultadoSync.error, 'No se pudo conectar con la nube: ${mensajeDe(e)}');
    }

    _sincronizando = true;
    notifyListeners();
    try {
      final r = await DatosNube.subirPendientes(clavesTablas);
      await _prefs.marcarSincronizacion();
      _version++;
      if (r.fallidos > 0) {
        return ResultadoSync(TipoResultadoSync.aviso,
            'Sincronización con avisos: ${r.fallidos} cambio(s) no se pudieron subir (se reintentan la próxima vez).');
      }
      return ResultadoSync(
        TipoResultadoSync.exito,
        r.subidos > 0 ? '¡Listo! Se subieron ${r.subidos} cambio(s) y se actualizaron los datos.' : '¡Listo! Datos actualizados.',
      );
    } catch (e) {
      return esErrorDeRed(e) ? _sinConexion : ResultadoSync(TipoResultadoSync.error, 'Error en la sincronización: ${mensajeDe(e)}');
    } finally {
      _sincronizando = false;
      notifyListeners();
      await actualizarPendientes();
    }
  }

  static const _sinConexion =
      ResultadoSync(TipoResultadoSync.error, 'Sin conexión a internet. Los datos quedan guardados en este equipo.');

  /// Sin sesión de Supabase Auth (p. ej. se entró sin internet) se pide la clave para abrirla.
  Future<bool> _asegurarSesionNube(String correoSesion, PedirClaveNube pedirClave) async {
    final sesion = _nube.auth.currentSession;
    if (sesion != null) {
      if (!sesion.isExpired) return true;
      try {
        final r = await _nube.auth.refreshSession();
        if (r.session != null) return true;
      } catch (e) {
        if (esErrorDeRed(e)) rethrow;
      }
    }

    var correo = correoSesion;
    var error = '';
    for (var intento = 0; intento < 3; intento++) {
      final r = await pedirClave(correo, error);
      if (r == null) return false;
      correo = r.correo;
      try {
        final res = await _nube.auth.signInWithPassword(email: r.correo, password: r.clave);
        if (res.session != null) return true;
        error = 'No se pudo iniciar sesión.';
      } catch (e) {
        if (esErrorDeRed(e)) rethrow;
        error = RegExp('invalid', caseSensitive: false).hasMatch(mensajeDe(e))
            ? 'Contraseña incorrecta.'
            : 'No se pudo iniciar sesión: ${mensajeDe(e)}';
      }
    }
    return false;
  }
}
