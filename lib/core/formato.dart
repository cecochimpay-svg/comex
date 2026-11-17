import 'package:flutter/services.dart';

/// Número al estilo es-AR: punto de miles, coma decimal y sin ceros sobrantes
/// (igual que `toLocaleString('es-AR', { maximumFractionDigits })` de la versión de escritorio).
String fmtNum(num? n, {int decimales = 0}) {
  final fijo = (n ?? 0).abs().toStringAsFixed(decimales);
  final partes = fijo.split('.');
  final entero = partes[0];
  final sb = StringBuffer();
  for (var i = 0; i < entero.length; i++) {
    if (i > 0 && (entero.length - i) % 3 == 0) sb.write('.');
    sb.write(entero[i]);
  }
  final dec = partes.length > 1 ? partes[1].replaceFirst(RegExp(r'0+$'), '') : '';
  final esCero = RegExp(r'^[0.]+$').hasMatch(fijo);
  return '${(n ?? 0) < 0 && !esCero ? '-' : ''}$sb${dec.isEmpty ? '' : ',$dec'}';
}

/// Lee lo escrito en un campo numérico (coma decimal). Vacío o inválido -> null.
double? leerNum(String texto) {
  final t = texto.trim().replaceAll(',', '.');
  return t.isEmpty ? null : double.tryParse(t);
}

/// Valor inicial de un campo numérico: sin separador de miles y con coma decimal.
String numEntrada(num? n) {
  if (n == null) return '';
  if (n == n.roundToDouble()) return '${n.round()}';
  return n.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceAll('.', ',');
}

/// Fecha de hoy como AAAA-MM-DD (formato de las columnas de fecha locales).
String hoyIso() => fechaIso(DateTime.now());

String fechaIso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// AAAA-MM-DD -> DD/MM/AAAA (si no tiene ese formato, lo devuelve tal cual).
String fechaCorta(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  return m == null ? iso : '${m[3]}/${m[2]}/${m[1]}';
}

/// Entrada decimal: sólo dígitos y una coma (el punto se convierte en coma, así "1.5" del teclado numérico
/// no se confunde con un separador de miles).
class EntradaDecimal extends TextInputFormatter {
  const EntradaDecimal({this.decimales = true});

  final bool decimales;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue anterior, TextEditingValue nuevo) {
    var t = nuevo.text.replaceAll('.', ',').replaceAll(RegExp(decimales ? r'[^0-9,]' : r'[^0-9]'), '');
    final coma = t.indexOf(',');
    if (coma >= 0) t = t.substring(0, coma + 1) + t.substring(coma + 1).replaceAll(',', '');
    if (t == nuevo.text) return nuevo;
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}
