import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nav/catalogo.dart';

/// Preferencias del equipo: accesos recientes, última sincronización y modo claro / noche.
class Preferencias extends ChangeNotifier {
  Preferencias._(this._p);

  static Future<Preferencias> cargar() async => Preferencias._(await SharedPreferences.getInstance());

  final SharedPreferences _p;

  static const _kRecientes = 'agrosoft_recientes_v1';
  static const _kUltimaSync = 'comex_ultima_sync';
  static const _kModoOscuro = 'comex_modo_oscuro';
  static const _maxRecientes = 4;

  List<String> get recientes =>
      (_p.getStringList(_kRecientes) ?? const []).where(indicePantallas.containsKey).toList();

  Future<void> registrarReciente(String ref) async {
    if (!indicePantallas.containsKey(ref)) return;
    final lista = [ref, ...recientes.where((r) => r != ref)].take(_maxRecientes).toList();
    if (listEquals(lista, recientes)) return;
    await _p.setStringList(_kRecientes, lista);
    notifyListeners();
  }

  DateTime? get ultimaSincronizacion => DateTime.tryParse(_p.getString(_kUltimaSync) ?? '')?.toLocal();

  Future<void> marcarSincronizacion() async {
    await _p.setString(_kUltimaSync, DateTime.now().toUtc().toIso8601String());
    notifyListeners();
  }

  /// Modo noche elegido en este equipo; null si nunca eligió (sigue el tema del sistema).
  bool? get modoOscuro => _p.getBool(_kModoOscuro);

  Future<void> guardarModoOscuro(bool oscuro) => _p.setBool(_kModoOscuro, oscuro);
}
