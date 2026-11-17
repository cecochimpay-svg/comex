import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../db/base_local.dart';
import '../red.dart';
import 'clave_hash.dart';
import 'sesion.dart';

/// Login de COMEX — misma lógica que seguridad/seguridad.js de la versión Electron:
///   1° RPC comex_login (valida usuario y clave contra comex_usuarios, con bloqueo en el servidor)
///   2° Supabase Auth con el correo interno `<usuario>@comex.cecoargentina.com` (sin esta sesión la
///      base no entrega datos: RLS de 004_acceso_con_sesion.sql)
///   Sin internet: verificador local scrypt de la última clave validada en este equipo (7 días).
/// Bloqueo local por intentos fallidos y sesión que vence a las 12 h.
class AuthServicio {
  AuthServicio(this._nube);

  final SupabaseClient _nube;
  final _intentos = <String, _Intento>{};
  static const _global = '*global*';

  Database get _db => BaseLocal.db;

  Future<ResultadoLogin> login(String usuario, String clave) async {
    final u = usuario.trim();
    final k = clave.trim();
    if (u.isEmpty || k.isEmpty) {
      return const ResultadoLogin.error('Completá el usuario y la contraseña para continuar.');
    }
    if (u.length > 120 || k.length > 200) {
      return const ResultadoLogin.error('Usuario o contraseña incorrectos.');
    }
    final clave_ = u.toLowerCase();
    final espera = max(_segundosBloqueo(clave_), _segundosBloqueo(_global));
    if (espera > 0) {
      return ResultadoLogin.error('Demasiados intentos. Esperá ${espera < 60 ? '$espera segundos' : '${(espera / 60).ceil()} minuto(s)'}.');
    }

    _Resultado r;
    var offline = false;
    try {
      r = await _loginOnline(u, k);
      if (r.ok) await _guardarVerificadorLocal(u, k, r.usuario);
    } catch (e) {
      if (!esErrorDeRed(e)) {
        return ResultadoLogin.error('No se pudo validar el ingreso: ${mensajeDe(e)}');
      }
      // Sin internet o Supabase caído: se valida contra el verificador local
      offline = true;
      r = await _loginOffline(u, k);
    }

    if (!r.ok) {
      if (r.motivo == 'credenciales') {
        _registrarFallo(clave_);
        _registrarFallo(_global);
        await Future<void>.delayed(const Duration(milliseconds: 400)); // frena la fuerza bruta
      }
      return ResultadoLogin.error(_mensajeError(r));
    }
    _intentos.remove(clave_);
    return ResultadoLogin.ok(await _guardarSesion(r.usuario, offline));
  }

  /// Sesión guardada en este equipo (null si no hay o venció).
  Future<Sesion?> sesionActual() async {
    final filas = await _db.rawQuery('SELECT * FROM sesion_activa WHERE id = 1');
    if (filas.isEmpty) return null;
    final s = filas.first;
    final nombre = _texto(s['nombre_usuario']);
    if (nombre == null || _texto(s['token']) == null) return null;

    final inicio = DateTime.tryParse('${s['fecha_inicio'] ?? ''}');
    final edadHoras = inicio == null ? -1 : DateTime.now().toUtc().difference(inicio).inMinutes / 60;
    if (!(edadHoras >= 0 && edadHoras < Config.sesionHoras)) {
      await _db.delete('sesion_activa');
      return null;
    }
    return Sesion(
      usuarioId: (s['usuario_id'] as num?)?.toInt() ?? 0,
      nombre: nombre,
      rol: _texto(s['rol']) ?? 'COMEX',
      correo: _texto(s['correo']) ?? Config.correoInterno(nombre),
      offline: _nube.auth.currentSession == null,
    );
  }

  Future<void> logout() async {
    try {
      await _nube.auth.signOut();
    } catch (_) {
      // Sin internet: igual se borra la sesión guardada
    }
    await _db.delete('sesion_activa');
  }

  // ---------------------------------------------------------------------------
  // Online
  // ---------------------------------------------------------------------------
  Future<_Resultado> _loginOnline(String usuario, String clave) async {
    final equipo = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final data = await _nube.rpc(
      'comex_login',
      params: {'p_usuario': usuario, 'p_clave': clave, 'p_equipo': 'COMEX Flutter · $equipo'},
    );
    final fila = _primeraFila(data);
    if (fila == null) return const _Resultado.rechazado('credenciales');
    if (fila['ok'] != true) {
      return _Resultado.rechazado(_texto(fila['motivo']) ?? 'credenciales', extra: fila);
    }
    final perfil = sinSecretos(fila)..putIfAbsent('usuario', () => usuario);

    // Sesión de Supabase Auth: sin ella RLS no entrega vuelos ni programas.
    try {
      await _nube.auth.signInWithPassword(email: Config.correoInterno(usuario), password: clave);
    } catch (e) {
      if (esErrorDeRed(e)) rethrow;
      // La cuenta de Auth la crea el trigger de 004; si todavía no existe se entra igual (sin datos protegidos).
    }
    return _Resultado.aceptado(perfil);
  }

  // ---------------------------------------------------------------------------
  // Offline
  // ---------------------------------------------------------------------------
  Future<_Resultado> _loginOffline(String usuario, String clave) async {
    final creds = await _db.rawQuery(
      'SELECT * FROM credenciales_locales WHERE correo = ?',
      [usuario.toLowerCase()],
    );
    if (creds.isEmpty) return const _Resultado.rechazado('sin_conexion');
    final c = creds.first;
    final validado = DateTime.tryParse('${c['actualizado'] ?? ''}');
    if (validado == null || DateTime.now().difference(validado).inDays >= Config.diasIngresoOffline) {
      return const _Resultado.rechazado('offline_vencido');
    }
    if (!await verificarClave(clave, '${c['hash'] ?? ''}')) return const _Resultado.rechazado('credenciales');
    var perfil = <String, Object?>{'usuario': usuario};
    try {
      perfil = Map<String, Object?>.from(jsonDecode('${c['usuario_json'] ?? '{}'}') as Map);
    } catch (_) {
      // json dañado: alcanza con el nombre
    }
    return _Resultado.aceptado(perfil);
  }

  Future<void> _guardarVerificadorLocal(String usuario, String clave, Map<String, Object?> perfil) async {
    await _db.rawInsert(
      'INSERT OR REPLACE INTO credenciales_locales (correo, hash, usuario_json, actualizado) VALUES (?, ?, ?, ?)',
      [
        usuario.toLowerCase(),
        await hashClave(clave),
        jsonEncode(sinSecretos(perfil), toEncodable: (o) => '$o'),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  Future<Sesion> _guardarSesion(Map<String, Object?> perfil, bool offline) async {
    final nombre = _texto(perfil['usuario']) ?? 'usuario';
    final rol = (_texto(perfil['rol']) ?? 'COMEX').toUpperCase();
    final id = int.tryParse('${perfil['id'] ?? ''}') ?? 0;
    final correo = Config.correoInterno(nombre);

    await _db.delete('sesion_activa');
    await _db.insert('sesion_activa', {
      'id': 1,
      'usuario_id': id,
      'nombre_usuario': nombre,
      'token': aHex(bytesAleatorios(32)),
      'fecha_inicio': DateTime.now().toUtc().toIso8601String(),
      'rol': rol,
      'correo': correo,
    });
    return Sesion(usuarioId: id, nombre: nombre, rol: rol, correo: correo, offline: offline);
  }

  String _mensajeError(_Resultado r) {
    switch (r.motivo) {
      case 'bloqueado':
        final hasta = DateTime.tryParse('${r.extra['hasta'] ?? ''}')?.toLocal();
        final hora = hasta == null
            ? ''
            : ' hasta las ${hasta.hour.toString().padLeft(2, '0')}:${hasta.minute.toString().padLeft(2, '0')}';
        return 'Usuario bloqueado por intentos fallidos$hora.';
      case 'inactivo':
        return 'El usuario está inactivo. Consultá con el administrador.';
      case 'sin_conexion':
        return 'Sin conexión. Solo pueden ingresar usuarios que ya ingresaron en este equipo.';
      case 'offline_vencido':
        return 'Sin conexión y hace más de ${Config.diasIngresoOffline} días que no ingresás con internet en este equipo.';
      default:
        final restantes = r.extra['restantes'];
        return restantes != null
            ? 'Usuario o contraseña incorrectos. Quedan $restantes intento(s).'
            : 'Usuario o contraseña incorrectos.';
    }
  }

  // ---------------------------------------------------------------------------
  // Bloqueo local por intentos fallidos: 5 fallos -> 30 s, 60 s, 120 s… hasta 15 minutos
  // ---------------------------------------------------------------------------
  int _segundosBloqueo(String clave) {
    final r = _intentos[clave];
    if (r == null) return 0;
    final resto = r.bloqueadoHasta.difference(DateTime.now()).inSeconds;
    return resto > 0 ? resto : 0;
  }

  void _registrarFallo(String clave) {
    final r = _intentos.putIfAbsent(clave, _Intento.new);
    r.fallos += 1;
    if (r.fallos >= 5) {
      final segundos = min(900, 30 * pow(2, r.fallos - 5).toInt());
      r.bloqueadoHasta = DateTime.now().add(Duration(seconds: segundos));
    }
  }
}

// -----------------------------------------------------------------------------
// Utilidades
// -----------------------------------------------------------------------------
const _camposSensibles = {'pass', 'clave', 'password', 'clave_hash', 'hash'};

/// Saca cualquier dato de contraseña.
Map<String, Object?> sinSecretos(Map<String, Object?> fila) =>
    {for (final e in fila.entries) if (!_camposSensibles.contains(e.key)) e.key: e.value};

Map<String, Object?>? _primeraFila(Object? data) {
  if (data is List && data.isNotEmpty && data.first is Map) return Map<String, Object?>.from(data.first as Map);
  if (data is Map) return Map<String, Object?>.from(data);
  return null;
}

String? _texto(Object? v) {
  final t = v?.toString().trim() ?? '';
  return t.isEmpty ? null : t;
}

class _Intento {
  int fallos = 0;
  DateTime bloqueadoHasta = DateTime.fromMillisecondsSinceEpoch(0);
}

class _Resultado {
  const _Resultado.aceptado(this.usuario)
      : ok = true,
        motivo = null,
        extra = const {};
  const _Resultado.rechazado(String this.motivo, {this.extra = const {}})
      : ok = false,
        usuario = const {};

  final bool ok;
  final String? motivo;
  final Map<String, Object?> usuario;
  final Map<String, Object?> extra;
}
