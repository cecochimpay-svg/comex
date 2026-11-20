import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/sesion.dart';
import '../db/filas.dart';
import '../registro/registro.dart';

/// Avisos para el administrador: cada alta, edición o baja de un despacho hecha por un usuario que no es
/// ADM queda en `comex_notificaciones` (la carga un trigger, migración 007 del repo comex). La app los
/// muestra flotando hasta que el ADM los cierra; cerrar uno lo marca cerrado para todos los ADM.

/// Un cambio en un despacho.
class AvisoCambio {
  const AvisoCambio({
    required this.id,
    required this.fecha,
    required this.usuario,
    required this.accion,
    this.registro = '',
    this.awb = '',
    this.destino = '',
    this.vuelo = '',
    this.semana,
    this.cambios = const {},
  });

  factory AvisoCambio.desde(Map<String, dynamic> f) {
    final cambios = <String, (Object?, Object?)>{};
    var c = f['cambios'];
    if (c is String && c.isNotEmpty) {
      try {
        c = jsonDecode(c);
      } catch (_) {
        c = null;
      }
    }
    if (c is Map) {
      for (final e in c.entries) {
        final v = e.value;
        if (v is List && v.length == 2) cambios['${e.key}'] = (v[0], v[1]);
      }
    }
    return AvisoCambio(
      id: (f['id'] as num).toInt(),
      fecha: DateTime.tryParse('${f['fecha'] ?? ''}')?.toLocal() ?? DateTime.now(),
      usuario: txt(f['usuario']),
      accion: txt(f['accion']).toUpperCase(),
      registro: txt(f['registro']),
      awb: txt(f['awb']),
      destino: txt(f['destino']).toUpperCase(),
      vuelo: txt(f['vuelo']).toUpperCase(),
      semana: f['semana'] == null ? null : numDe(f['semana']).toInt(),
      cambios: cambios,
    );
  }

  final int id;
  final DateTime fecha;

  /// Quién hizo el cambio.
  final String usuario;

  /// ALTA, EDICION o BAJA.
  final String accion;
  final String registro;
  final String awb;
  final String destino;
  final String vuelo;
  final int? semana;

  /// En una edición: columna -> (antes, después).
  final Map<String, (Object?, Object?)> cambios;
}

/// Los avisos de un mismo usuario, del más nuevo al más viejo.
class GrupoAvisos {
  const GrupoAvisos(this.usuario, this.avisos);

  final String usuario;
  final List<AvisoCambio> avisos;

  DateTime get ultimo => avisos.first.fecha;
  int cuantos(String accion) => avisos.where((a) => a.accion == accion).length;
}

/// De dónde salen los avisos (Supabase en la app, una falsa en los tests).
abstract class FuenteAvisos {
  /// Avisos sin cerrar.
  Future<List<Map<String, dynamic>>> abiertos();

  /// Escucha en tiempo real: [nuevo] con cada aviso que llega, [cerrado] con el id del que cerró otro ADM.
  /// Devuelve la función para dejar de escuchar.
  void Function() escuchar({
    required void Function(Map<String, dynamic> fila) nuevo,
    required void Function(int id) cerrado,
  });

  Future<void> cerrar(List<int> ids, String quien);
}

class FuenteAvisosSupabase implements FuenteAvisos {
  FuenteAvisosSupabase(this._nube);

  final SupabaseClient _nube;
  static const tabla = 'comex_notificaciones';

  @override
  Future<List<Map<String, dynamic>>> abiertos() async => await _nube
      .from(tabla)
      .select()
      .eq('cerrada', false)
      .order('fecha', ascending: false)
      .limit(500)
      .timeout(const Duration(seconds: 10));

  @override
  void Function() escuchar({
    required void Function(Map<String, dynamic> fila) nuevo,
    required void Function(int id) cerrado,
  }) {
    final canal = _nube
        .channel('comex_avisos_admin')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: tabla,
          callback: (p) {
            final f = p.newRecord;
            if (p.eventType == PostgresChangeEvent.insert && f['id'] != null) {
              nuevo(f);
            } else if (p.eventType == PostgresChangeEvent.update && f['cerrada'] == true && f['id'] != null) {
              cerrado((f['id'] as num).toInt());
            }
          },
        )
        .subscribe();
    return () => _nube.removeChannel(canal);
  }

  @override
  Future<void> cerrar(List<int> ids, String quien) async {
    if (ids.isEmpty) return;
    await _nube
        .from(tabla)
        .update({'cerrada': true, 'cerrada_por': quien, 'cerrada_en': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', ids)
        .timeout(const Duration(seconds: 10));
  }
}

/// Estado de los avisos para la pantalla. Sólo trabaja con un ADM logueado.
class AvisosAdmin extends ChangeNotifier {
  AvisosAdmin(this._fuente, {this.revisarCada = const Duration(minutes: 2)});

  final FuenteAvisos _fuente;

  /// Además del tiempo real, se relee cada tanto (por si el tiempo real se cortó).
  final Duration revisarCada;

  final _avisos = <int, AvisoCambio>{};

  /// Cerrados en este equipo que todavía no se pudieron marcar en la nube (sin conexión).
  final _cerradosSinSubir = <int>{};
  String? _admin;
  Timer? _reloj;
  void Function()? _dejarDeEscuchar;

  /// Avisos agrupados por usuario; primero el grupo con el cambio más reciente.
  List<GrupoAvisos> get grupos {
    final porUsuario = <String, List<AvisoCambio>>{};
    for (final a in _avisos.values) {
      porUsuario.putIfAbsent(a.usuario.isEmpty ? '—' : a.usuario, () => []).add(a);
    }
    final r = [
      for (final e in porUsuario.entries) GrupoAvisos(e.key, e.value..sort((a, b) => b.fecha.compareTo(a.fecha))),
    ]..sort((a, b) => b.ultimo.compareTo(a.ultimo));
    return r;
  }

  int get total => _avisos.length;

  /// Llamar cada vez que cambia la sesión: con un ADM empieza a escuchar; con otro usuario (o sin sesión) se apaga.
  Future<void> seguir(Sesion? s) async {
    final admin = s != null && s.esAdministrador ? s.nombre : null;
    if (admin == _admin) return;
    _detener();
    _admin = admin;
    _avisos.clear();
    _cerradosSinSubir.clear();
    notifyListeners();
    if (admin == null) return;

    try {
      _dejarDeEscuchar = _fuente.escuchar(
        nuevo: (f) {
          try {
            final a = AvisoCambio.desde(f);
            if (_cerradosSinSubir.contains(a.id)) return;
            _avisos[a.id] = a;
            notifyListeners();
          } catch (e) {
            anotar('Avisos: aviso con formato inesperado: $e');
          }
        },
        cerrado: (id) {
          if (_avisos.remove(id) != null) notifyListeners();
        },
      );
    } catch (e) {
      anotar('Avisos: no se pudo escuchar en tiempo real: $e');
    }
    _reloj = Timer.periodic(revisarCada, (_) => recargar());
    await recargar();
  }

  /// Relee los avisos abiertos (y reintenta marcar los que se cerraron sin conexión).
  Future<void> recargar() async {
    final admin = _admin;
    if (admin == null) return;
    try {
      if (_cerradosSinSubir.isNotEmpty) {
        await _fuente.cerrar(_cerradosSinSubir.toList(), admin);
        _cerradosSinSubir.clear();
      }
    } catch (_) {
      // Sigue sin conexión: se reintenta en la próxima vuelta.
    }
    try {
      final filas = await _fuente.abiertos();
      if (_admin != admin) return; // cambió la sesión mientras tanto
      _avisos
        ..clear()
        ..addEntries([
          for (final f in filas)
            if (!_cerradosSinSubir.contains((f['id'] as num?)?.toInt())) MapEntry((f['id'] as num).toInt(), AvisoCambio.desde(f)),
        ]);
      notifyListeners();
    } catch (e) {
      // Sin conexión o la migración 007 todavía no se corrió: no hay avisos para mostrar.
      anotar('Avisos: no se pudieron leer: $e');
    }
  }

  /// Cierra los avisos de un usuario (el ADM tocó la X).
  Future<void> cerrarGrupo(String usuario) =>
      _cerrar([for (final a in _avisos.values) if ((a.usuario.isEmpty ? '—' : a.usuario) == usuario) a.id]);

  Future<void> cerrarTodos() => _cerrar(_avisos.keys.toList());

  Future<void> _cerrar(List<int> ids) async {
    final admin = _admin;
    if (admin == null || ids.isEmpty) return;
    for (final id in ids) {
      _avisos.remove(id);
    }
    notifyListeners();
    try {
      await _fuente.cerrar(ids, admin);
    } catch (e) {
      _cerradosSinSubir.addAll(ids);
      anotar('Avisos: cerrados sin conexión, se marcan después: $e');
    }
  }

  void _detener() {
    _reloj?.cancel();
    _reloj = null;
    try {
      _dejarDeEscuchar?.call();
    } catch (_) {
      // El canal ya estaba cerrado.
    }
    _dejarDeEscuchar = null;
  }

  @override
  void dispose() {
    _detener();
    super.dispose();
  }
}
