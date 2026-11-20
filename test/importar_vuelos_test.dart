import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:comex/core/importar/lector_xlsx.dart';
import 'package:comex/features/vuelos/importar_vuelos.dart';
import 'package:comex/features/vuelos/vuelos_datos.dart';
import 'package:flutter_test/flutter_test.dart';

/// Celda de fecha (estilo 1 = dd/mm/yyyy) u hora (estilo 2 = h:mm) para el .xlsx de prueba.
class _Fecha {
  const _Fecha(this.serie);
  final double serie;
}

class _Hora {
  const _Hora(this.fraccion);
  final double fraccion;
}

/// Serie de Excel de una fecha.
double serie(int a, int m, int d) => DateTime.utc(a, m, d).difference(DateTime.utc(1899, 12, 30)).inDays.toDouble();

/// Arma un .xlsx mínimo (como el que baja Excel o Google Sheets) con textos compartidos y estilos de fecha.
Uint8List xlsx(List<List<Object?>> filas, {String hoja = 'Hoja1'}) {
  final textos = <String>[];
  String col(int i) {
    var s = '';
    var n = i + 1;
    while (n > 0) {
      s = String.fromCharCode(65 + (n - 1) % 26) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  final sb = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>');
  for (var r = 0; r < filas.length; r++) {
    sb.write('<row r="${r + 1}">');
    for (var c = 0; c < filas[r].length; c++) {
      final v = filas[r][c];
      final ref = '${col(c)}${r + 1}';
      switch (v) {
        case null:
          break;
        case String s:
          textos.add(s);
          sb.write('<c r="$ref" t="s"><v>${textos.length - 1}</v></c>');
        case _Fecha f:
          sb.write('<c r="$ref" s="1"><v>${f.serie}</v></c>');
        case _Hora h:
          sb.write('<c r="$ref" s="2"><v>${h.fraccion}</v></c>');
        case num n:
          sb.write('<c r="$ref"><v>$n</v></c>');
      }
    }
    sb.write('</row>');
  }
  sb.write('</sheetData></worksheet>');

  final compartidos = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>'
      '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
  for (final t in textos) {
    compartidos.write('<si><t>${esc(t)}</t></si>');
  }
  compartidos.write('</sst>');

  const estilos = '<?xml version="1.0" encoding="UTF-8"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="1"><numFmt numFmtId="164" formatCode="dd/mm/yyyy"/></numFmts>'
      '<cellXfs count="3"><xf numFmtId="0"/><xf numFmtId="164"/><xf numFmtId="20"/></cellXfs>'
      '</styleSheet>';
  final libro = '<?xml version="1.0" encoding="UTF-8"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="$hoja" sheetId="1" r:id="rId1"/></sheets></workbook>';
  const rels = '<?xml version="1.0" encoding="UTF-8"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet1.xml"/></Relationships>';

  final zip = Archive();
  void agregar(String ruta, String texto) {
    final b = utf8.encode(texto);
    zip.addFile(ArchiveFile(ruta, b.length, b));
  }

  agregar('xl/workbook.xml', libro);
  agregar('xl/_rels/workbook.xml.rels', rels);
  agregar('xl/styles.xml', estilos);
  agregar('xl/sharedStrings.xml', compartidos.toString());
  agregar('xl/worksheets/sheet1.xml', sb.toString());
  return Uint8List.fromList(ZipEncoder().encode(zip)!);
}

/// Planilla de Jetcargo (captura de mcurcio): todas las columnas, fechas y horas de Excel, AWB repetidos.
Uint8List planillaJetcargo() {
  const titulos = [
    'SEMANA', 'Dia', 'Ingreso', 'CLIENTE', 'CONSIGNEE', 'REF', 'PALLETS', 'CAJAS', 'KILOS', 'DESTINO',
    'LINEA AEREA', 'AWB', 'VUELO', 'FECHA ETD1', 'HORA ETD1', 'FECHA ETA 1', 'HORA ETA1', 'VUELO CNX',
    'FECHA ETD2', 'HORA ETD2', 'FECHA ETA 2', 'HORA ETA2', 'STATUS', 'TARIFA /KG', 'FIJOS / AWB', 'TARIFA',
    'FUEL', 'SSC', 'FIJOS',
  ];
  List<Object?> fila(String awb, String vuelo, int dEtd, String hEtd, String cnx, String tarifa) {
    final h = hEtd.split(':');
    return [
      47.0, 5.0, _Fecha(serie(2026, 11, 20)), 'CECO', null, null, 5.0, null, 3250.0, 'CAN',
      vuelo, awb, vuelo, _Fecha(serie(2026, 11, dEtd)), _Hora((int.parse(h[0]) * 60 + int.parse(h[1])) / 1440),
      _Fecha(serie(2026, 11, 22)), _Hora(30 / 1440), cnx, _Fecha(serie(2026, 11, 23)), _Hora(10 * 60 / 1440 + 40 / 1440),
      _Fecha(serie(2026, 11, 23)), _Hora((21 * 60 + 40) / 1440), null, tarifa, 'USD 85,00', 2.5, 0.66, null, '######',
    ];
  }

  return xlsx([
    titulos,
    fila('176-69302763', 'EK248', 20, '21:30', 'EK362', 'USD 3,16'),
    fila('071-63266814', 'ET507', 21, '21:30', 'ET606', 'USD 2,71'),
    fila('071-63266814', 'ET507', 21, '21:30', 'ET606', 'USD 2,71'),
    fila('071-63266814', 'ET507', 21, '21:30', 'ET606', 'USD 2,71'),
    [],
  ]);
}

/// Planilla de TCI (captura de mmendy): logo arriba, títulos en la fila 5 y banda "WEEK 46 / 2026".
Uint8List planillaTci() => xlsx([
  [],
  [],
  [null, null, null, null, null, 'TCI | TRUST CARGO INTERNATIONAL'],
  [],
  ['AWB', 'INGRESO TCA REQUERIDO', 'DESTINO', 'RUTA', 'VUELO', 'PROFORMA', 'ETD', 'CONEX', 'ETA', 'TARIMAS', 'PESO',
    'TARIFA', 'STATUS', 'CNNE'],
  ['WEEK 46 / 2026'],
  ['020-04387655', '22/11/2026', 'pvg', 'EZE-FRA-PVG', 'LH511', 'PF-77', '23/11/2026 16:45', 'LH728', '25/11/2026 07:00',
    '5', '3.250', 3.45, 'confirmed', 'SHANGHAI FRESH'],
  [null, null, null, null, null, null, null, null, null, null, null, null, null, null],
]);

Vuelo existente(Map<String, Object?> f) => Vuelo({'registro': 'R${f['awb']}${f['n'] ?? ''}', 'usuario': 'mcurcio', ...f});

void main() {
  test('normaliza los títulos de las dos planillas', () {
    expect(normalizarEncabezado('FECHA ETA 1'), 'FECHA ETA1');
    expect(normalizarEncabezado('TARIFA /KG'), 'TARIFA KG');
    expect(normalizarEncabezado('FIJOS / AWB'), 'FIJOS AWB');
    expect(normalizarEncabezado('Línea aérea'), 'LINEA AEREA');
    expect(normalizarEncabezado('INGRESO TCA REQUERIDO'), 'INGRESO TCA REQUERIDO');
  });

  test('lee la planilla de Jetcargo con todas sus columnas', () {
    final p = leerPlanillaVuelos(planillaJetcargo());
    expect(p.filaEncabezado, 1);
    expect(p.filas, hasLength(4));
    expect(p.columnas, containsAll([CampoPlanilla.eta2, CampoPlanilla.lineaAerea, CampoPlanilla.fijos]));

    final d = p.filas.first.datos;
    expect(d['awb'], '176-69302763');
    expect(d['ingreso'], '2026-11-20');
    expect(d['pcs'], 5);
    expect(d['kilos'], 3250);
    expect(d['destino'], 'CAN');
    expect(d['linea_aerea'], 'EK248');
    expect(d['fecha_etd1'], '2026-11-20');
    expect(d['hora_etd1'], '21:30');
    expect(d['fecha_eta_1'], '2026-11-22');
    expect(d['hora_eta1'], '00:30');
    expect(d['vuelo_cnx'], 'EK362');
    expect(d['fecha_etd2'], '2026-11-23');
    expect(d['hora_etd2'], '10:40');
    expect(d['fecha_eta_2'], '2026-11-23');
    expect(d['hora_eta2'], '21:40');
    // "TARIFA /KG" (con fuel) le gana a "TARIFA"; los "######" no se importan.
    expect(d['tarifa_kg'], 'USD 3,16');
    expect(d['fijos'], 'USD 85,00');
    expect(d['cliente'], 'CECO');
    expect(d.containsKey('status'), isFalse);
    expect(p.filas.first.avisos, isEmpty);
  });

  test('lee la planilla de TCI salteando el logo y la banda WEEK', () {
    final p = leerPlanillaVuelos(planillaTci());
    expect(p.filaEncabezado, 5);
    expect(p.ignoradas, 1);
    expect(p.filas, hasLength(1));
    final f = p.filas.single;
    expect(f.numero, 7);
    expect(f.datos['destino'], 'PVG');
    expect(f.datos['ruta'], 'EZE-FRA-PVG');
    expect(f.datos['ingreso'], '2026-11-22');
    expect(f.datos['fecha_etd1'], '2026-11-23');
    expect(f.datos['hora_etd1'], '16:45');
    expect(f.etaFecha, '2026-11-25');
    expect(f.etaHora, '07:00');
    expect(f.datos['kilos'], 3250);
    expect(f.datos['pcs'], 5);
    expect(f.datos['tarifa_kg'], 'USD 3,45');
    expect(f.datos['status'], 'CONFIRMADO');
    expect(f.datos['consignatario'], 'SHANGHAI FRESH');
  });

  test('empareja por AWB: actualiza lo que cambió, crea lo que falta y no toca lo igual', () {
    final p = leerPlanillaVuelos(planillaJetcargo());
    final existentes = [
      // Igual a la planilla en lo que la planilla trae, salvo la tarifa.
      existente({
        'awb': '176 69302763', 'ingreso': '2026-11-20', 'cliente': 'CECO', 'pcs': 5, 'kilos': '3250', 'destino': 'CAN',
        'linea_aerea': 'EK248', 'vuelo': 'EK248', 'fecha_etd1': '2026-11-20', 'hora_etd1': '21:30:00',
        'fecha_eta_1': '2026-11-22', 'hora_eta1': '00:30', 'vuelo_cnx': 'EK362', 'fecha_etd2': '2026-11-23',
        'hora_etd2': '10:40', 'fecha_eta_2': '2026-11-23', 'hora_eta2': '21:40', 'tarifa_kg': 'USD 3,00',
        'fijos': 'USD 85,00',
      }),
      // El AWB repetido: hay 2 cargados y la planilla trae 3.
      existente({'awb': '071-63266814', 'n': 1, 'destino': 'CAN', 'pcs': 5, 'fecha_etd1': '2026-11-21'}),
      existente({'awb': '071-63266814', 'n': 2, 'destino': 'CAN', 'pcs': 5, 'fecha_etd1': '2026-11-21'}),
    ];
    final plan = compararConExistentes(p, existentes);
    expect(plan.map((c) => c.tipo), [TipoCambio.actualiza, TipoCambio.actualiza, TipoCambio.actualiza, TipoCambio.nuevo]);

    final tarifa = plan.first;
    expect(tarifa.cambios.keys, ['tarifa_kg']);
    expect(tarifa.detalle.single, ('Tarifa', 'USD 3,00', 'USD 3,16'));
    expect(plan[1].previo!.registro, 'R071-632668141');
    expect(plan[2].previo!.registro, 'R071-632668142');
    expect(plan[3].previo, isNull);
  });

  test('una fila sin cambios queda igual y una nueva sin destino da error', () {
    final p = leerPlanillaVuelos(planillaTci());
    final igual = existente({
      'awb': '020-04387655', 'ingreso': '2026-11-22', 'destino': 'PVG', 'ruta': 'EZE-FRA-PVG', 'vuelo': 'LH511',
      'proforma': 'PF-77', 'fecha_etd1': '2026-11-23', 'hora_etd1': '16:45', 'vuelo_cnx': 'LH728',
      'fecha_eta_1': '2026-11-25', 'hora_eta1': '07:00', 'pcs': 5, 'kilos': 3250, 'tarifa_kg': 'USD 3,45',
      'status': 'CONFIRMADO', 'consignatario': 'SHANGHAI FRESH',
    });
    expect(compararConExistentes(p, [igual]).single.tipo, TipoCambio.igual);

    // Despacho viejo con la ETA en el tramo 2: la ETA de TCI se compara (y guarda) ahí.
    final tramo2 = existente({...igual.f, 'fecha_eta_1': '2026-11-24', 'fecha_eta_2': '2026-11-26', 'hora_eta2': '07:00'});
    final c = compararConExistentes(p, [tramo2]).single;
    expect(c.tipo, TipoCambio.actualiza);
    expect(c.cambios, {'fecha_eta_2': '2026-11-25'});

    final sinDestino = xlsx([
      ['AWB', 'VUELO', 'DESTINO', 'PALLETS'],
      ['999-11112222', 'LH511', null, 4.0],
    ]);
    final e = compararConExistentes(leerPlanillaVuelos(sinDestino), const []).single;
    expect(e.tipo, TipoCambio.error);
  });

  test('valores sueltos', () {
    expect(leerFecha('21/11/2026'), ('2026-11-21', null));
    expect(leerFecha('2026-11-21 13:30'), ('2026-11-21', '13:30'));
    expect(leerFecha('31/11/2026'), (null, null));
    expect(leerHora('8:00'), '08:00');
    expect(leerHora('2130'), '21:30');
    expect(leerHora(0.5625), '13:30');
    expect(leerNumero('3.250'), 3250);
    expect(leerNumero('3.250,5'), 3250.5);
    expect(leerDinero('USD 2,48'), 'USD 2,48');
    expect(leerDinero(2.5), 'USD 2,50');
    expect(leerDinero('######'), isNull);
  });

  test('avisa si no es un .xlsx o no tiene títulos', () {
    expect(() => leerXlsx(Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0, 0])), throwsA(isA<ArchivoInvalido>()));
    expect(() => leerPlanillaVuelos(xlsx([['hola', 'chau'], ['1', '2']])), throwsA(isA<ArchivoInvalido>()));
  });
}
