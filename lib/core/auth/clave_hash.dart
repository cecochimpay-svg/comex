import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

// Verificador local de contraseña con scrypt (mismo formato que la versión de escritorio:
// "scrypt$<salt hex>$<hash hex>", N=16384 r=8 p=1, 64 bytes).
// En web el cálculo corre en el hilo de la pantalla: se usa N=4096 y se marca como "scrypt4096".
const _costoEscritorio = 16384;
const _costoWeb = 4096;
const _r = 8;
const _p = 1;
const _largo = 64;

Uint8List _scrypt(List<Object> args) {
  final clave = args[0] as Uint8List;
  final salt = args[1] as Uint8List;
  final costo = args[2] as int;
  final largo = args[3] as int;
  final kdf = Scrypt()..init(ScryptParameters(costo, _r, _p, largo, salt));
  return kdf.process(clave);
}

Future<Uint8List> _derivar(String clave, Uint8List salt, int costo, int largo) =>
    compute(_scrypt, <Object>[Uint8List.fromList(utf8.encode(clave)), salt, costo, largo]);

Future<String> hashClave(String clave) async {
  final salt = bytesAleatorios(16);
  const costo = kIsWeb ? _costoWeb : _costoEscritorio;
  final hash = await _derivar(clave, salt, costo, _largo);
  const tipo = costo == _costoEscritorio ? 'scrypt' : 'scrypt$costo';
  return '$tipo\$${aHex(salt)}\$${aHex(hash)}';
}

Future<bool> verificarClave(String clave, String guardado) async {
  try {
    final partes = guardado.split(r'$');
    if (partes.length != 3) return false;
    final costo = switch (partes[0]) {
      'scrypt' => _costoEscritorio,
      'scrypt4096' => _costoWeb,
      _ => 0,
    };
    if (costo == 0) return false;
    final salt = deHex(partes[1]);
    final esperado = deHex(partes[2]);
    if (salt.isEmpty || esperado.isEmpty) return false;
    final calculado = await _derivar(clave, salt, costo, esperado.length);
    return igualesBytes(esperado, calculado);
  } catch (_) {
    return false;
  }
}

/// Comparación en tiempo constante (no revela cuántos caracteres coinciden).
bool igualesBytes(List<int> a, List<int> b) {
  var diferencia = a.length ^ b.length;
  for (var i = 0; i < a.length; i++) {
    diferencia |= a[i] ^ (i < b.length ? b[i] : 0);
  }
  return diferencia == 0;
}

bool igualSeguro(String a, String b) => igualesBytes(utf8.encode(a), utf8.encode(b));

Uint8List bytesAleatorios(int cantidad) {
  final r = Random.secure();
  return Uint8List.fromList(List<int>.generate(cantidad, (_) => r.nextInt(256)));
}

String aHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List deHex(String hex) {
  if (hex.length.isOdd) return Uint8List(0);
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}
