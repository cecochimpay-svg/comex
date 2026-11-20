import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Hoja de un .xlsx leída tal cual: filas de celdas (null = vacía).
/// Cada celda es `String`, `double`, `bool` o `DateTime` (número con formato de fecha u hora).
class HojaXlsx {
  const HojaXlsx(this.nombre, this.filas);

  final String nombre;
  final List<List<Object?>> filas;
}

/// Error de lectura con un mensaje para mostrar.
class ArchivoInvalido implements Exception {
  const ArchivoInvalido(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Lee todas las hojas de un .xlsx (Excel, Google Sheets "Descargar → .xlsx", LibreOffice).
/// No necesita nada de la plataforma: anda igual en Windows, iPad y web.
List<HojaXlsx> leerXlsx(Uint8List bytes) {
  // Un .xls viejo (binario) empieza con D0 CF 11 E0; un .xlsx es un zip (PK).
  if (bytes.length >= 4 && bytes[0] == 0xD0 && bytes[1] == 0xCF) {
    throw const ArchivoInvalido('Es un .xls viejo. Abrilo en Excel y guardalo como .xlsx ("Libro de Excel").');
  }
  if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
    throw const ArchivoInvalido('El archivo no es un Excel .xlsx.');
  }

  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const ArchivoInvalido('No se pudo abrir el Excel: el archivo está dañado.');
  }

  XmlDocument? xml(String ruta) {
    final f = zip.findFile(ruta);
    if (f == null) return null;
    return XmlDocument.parse(utf8.decode(f.content as List<int>, allowMalformed: true));
  }

  final compartidos = _textosCompartidos(xml('xl/sharedStrings.xml'));
  final estilosFecha = _estilosDeFecha(xml('xl/styles.xml'));
  final hojas = <HojaXlsx>[];
  for (final (nombre, ruta) in _hojas(xml('xl/workbook.xml'), xml('xl/_rels/workbook.xml.rels'))) {
    final doc = xml(ruta);
    if (doc != null) hojas.add(HojaXlsx(nombre, _filas(doc, compartidos, estilosFecha)));
  }
  if (hojas.isEmpty) throw const ArchivoInvalido('El Excel no tiene hojas con datos.');
  return hojas;
}

/// (nombre, ruta dentro del zip) de cada hoja, en el orden de las pestañas.
List<(String, String)> _hojas(XmlDocument? libro, XmlDocument? rels) {
  final destinos = <String, String>{};
  for (final r in rels?.findAllElements('Relationship') ?? const <XmlElement>[]) {
    final id = r.getAttribute('Id');
    var destino = r.getAttribute('Target') ?? '';
    if (id == null || destino.isEmpty) continue;
    destino = destino.startsWith('/') ? destino.substring(1) : 'xl/$destino';
    destinos[id] = destino;
  }
  final r = <(String, String)>[];
  for (final h in libro?.findAllElements('sheet') ?? const <XmlElement>[]) {
    final id = h.getAttribute('r:id') ??
        h.attributes.where((a) => a.name.local == 'id').map((a) => a.value).firstOrNull;
    final ruta = destinos[id];
    if (ruta != null) r.add((h.getAttribute('name') ?? 'Hoja', ruta));
  }
  // Libro sin workbook.xml legible: se prueba la primera hoja por su nombre de siempre.
  if (r.isEmpty) r.add(('Hoja1', 'xl/worksheets/sheet1.xml'));
  return r;
}

List<String> _textosCompartidos(XmlDocument? doc) => [
  for (final si in doc?.findAllElements('si') ?? const <XmlElement>[])
    // Texto con formato (varios <r><t>): se juntan los pedazos; se saltean las guías fonéticas (<rPh>).
    si.descendantElements
        .where((e) => e.name.local == 't' && e.parentElement?.name.local != 'rPh')
        .map((e) => e.innerText)
        .join(),
];

/// Índices de estilo (atributo s de la celda) cuyo formato numérico es una fecha u hora.
Set<int> _estilosDeFecha(XmlDocument? doc) {
  if (doc == null) return const {};
  final propios = <int>{};
  for (final f in doc.findAllElements('numFmt')) {
    final id = int.tryParse(f.getAttribute('numFmtId') ?? '');
    // Se sacan los textos entre comillas y los colores/condiciones entre corchetes antes de buscar d, m, y, h.
    final codigo = (f.getAttribute('formatCode') ?? '')
        .replaceAll(RegExp(r'"[^"]*"'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .toLowerCase();
    if (id != null && RegExp(r'[dyh]|mm?:|:ss?').hasMatch(codigo) && !codigo.contains('0.0')) propios.add(id);
  }
  bool esFecha(int id) => (id >= 14 && id <= 22) || (id >= 45 && id <= 47) || propios.contains(id);

  final xfs = doc.findAllElements('cellXfs').firstOrNull;
  if (xfs == null) return const {};
  final r = <int>{};
  var i = 0;
  for (final xf in xfs.childElements.where((e) => e.name.local == 'xf')) {
    if (esFecha(int.tryParse(xf.getAttribute('numFmtId') ?? '') ?? 0)) r.add(i);
    i++;
  }
  return r;
}

List<List<Object?>> _filas(XmlDocument doc, List<String> compartidos, Set<int> estilosFecha) {
  final filas = <List<Object?>>[];
  for (final row in doc.findAllElements('row')) {
    final n = int.tryParse(row.getAttribute('r') ?? '');
    final indice = n == null ? filas.length : n - 1;
    while (filas.length < indice) {
      filas.add(<Object?>[]);
    }
    final fila = <Object?>[];
    var siguiente = 0;
    for (final c in row.childElements.where((e) => e.name.local == 'c')) {
      final col = _columna(c.getAttribute('r')) ?? siguiente;
      siguiente = col + 1;
      final valor = _valor(c, compartidos, estilosFecha);
      if (valor == null) continue;
      while (fila.length <= col) {
        fila.add(null);
      }
      fila[col] = valor;
    }
    if (indice < filas.length) {
      filas[indice] = fila;
    } else {
      filas.add(fila);
    }
  }
  return filas;
}

Object? _valor(XmlElement c, List<String> compartidos, Set<int> estilosFecha) {
  final tipo = c.getAttribute('t');
  final v = c.findElements('v').firstOrNull?.innerText;
  switch (tipo) {
    case 's':
      final i = int.tryParse(v ?? '');
      return i == null || i >= compartidos.length ? null : _textoONulo(compartidos[i]);
    case 'inlineStr':
      return _textoONulo(c.findAllElements('t').map((e) => e.innerText).join());
    case 'str':
      return _textoONulo(v ?? '');
    case 'b':
      return v == '1';
    case 'e':
      return null; // #N/A, #REF!…: se toma como vacía
  }
  if (v == null || v.trim().isEmpty) return null;
  final numero = double.tryParse(v.trim());
  if (numero == null) return _textoONulo(v);
  final estilo = int.tryParse(c.getAttribute('s') ?? '');
  if (estilo != null && estilosFecha.contains(estilo)) return fechaDeSerie(numero);
  return numero;
}

String? _textoONulo(String s) {
  final t = s.trim();
  return t.isEmpty ? null : t;
}

/// "AB12" -> 27 (columna en base 0).
int? _columna(String? ref) {
  if (ref == null) return null;
  var col = 0;
  var letras = 0;
  for (final u in ref.toUpperCase().codeUnits) {
    if (u < 65 || u > 90) break;
    col = col * 26 + (u - 64);
    letras++;
  }
  return letras == 0 ? null : col - 1;
}

/// Número de serie de Excel (días desde 30/12/1899, con la hora como fracción) a fecha y hora.
DateTime fechaDeSerie(double serie) {
  final ms = (serie * Duration.millisecondsPerDay).round();
  // Se redondea al minuto: 13:30 suele venir como 0.56249999…
  final base = DateTime.utc(1899, 12, 30).add(Duration(milliseconds: ms));
  final redondeo = base.second >= 30 ? 1 : 0;
  return DateTime.utc(base.year, base.month, base.day, base.hour, base.minute + redondeo);
}
