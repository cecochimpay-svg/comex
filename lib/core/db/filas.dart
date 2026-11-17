/// Fila de SQLite tal cual (columna -> valor) y lectores tolerantes a los tipos mezclados
/// que deja la base heredada (números guardados como texto, nulos, espacios).
typedef Fila = Map<String, Object?>;

double numDe(Object? v) => switch (v) {
  num n => n.toDouble(),
  String s => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0,
  _ => 0,
};

String txt(Object? v) => v == null ? '' : '$v'.trim();
