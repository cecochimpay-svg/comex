import 'dart:convert';

import 'package:comex/core/datos/datos_nube.dart';
import 'package:comex/core/db/base_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Copia local y cola offline de DatosNube contra una base SQLite real en memoria.
/// La "nube" es un Supabase inalcanzable (puerto cerrado): simula estar sin internet.
void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    await BaseLocal.usar(db);
    DatosNube.cliente = () => SupabaseClient('http://127.0.0.1:9', 'clave-de-prueba');
  });

  tearDown(() => db.close());

  Future<List<Map<String, Object?>>> filasLocales() => db.rawQuery('SELECT * FROM filas ORDER BY clave');

  test('leer guarda la copia y sin red la devuelve', () async {
    final online = await DatosNube.leer(
      tabla: 't',
      clave: 'registro',
      alcance: '2026|*',
      consulta: (_) async => [
        {'registro': 'A', 'awb': '1'},
        {'registro': 'B', 'awb': '2'},
      ],
    );
    expect(online.offline, isFalse);
    expect(online.filas.map((f) => f['registro']), unorderedEquals(['A', 'B']));

    final offline = await DatosNube.leer(
      tabla: 't',
      clave: 'registro',
      alcance: '2026|*',
      consulta: (_) => throw Exception('SocketException: Failed host lookup'),
    );
    expect(offline.offline, isTrue);
    expect(offline.filas.map((f) => f['registro']), unorderedEquals(['A', 'B']));
  });

  test('una nueva bajada reemplaza lo de ese alcance (lo borrado en la nube desaparece)', () async {
    Future<void> bajar(List<Map<String, dynamic>> filas) =>
        DatosNube.leer(tabla: 't', clave: 'registro', alcance: 'x', consulta: (_) async => filas);
    await bajar([{'registro': 'A'}, {'registro': 'B'}]);
    await bajar([{'registro': 'B', 'awb': 'nuevo'}]);
    final f = await filasLocales();
    expect(f.map((x) => x['clave']), ['B']);
    expect(jsonDecode(f.single['datos'] as String)['awb'], 'nuevo');
  });

  test('una fila bajada con otro alcance pasa al nuevo', () async {
    await DatosNube.leer(tabla: 't', clave: 'registro', alcance: 'juan', consulta: (_) async => [{'registro': 'A'}]);
    final r = await DatosNube.leer(
      tabla: 't',
      clave: 'registro',
      alcance: '*',
      consulta: (_) async => [{'registro': 'A'}],
    );
    expect(r.filas, hasLength(1));
    expect((await filasLocales()).single['alcance'], '*');
  });

  test('guardar sin red deja el cambio pendiente, con la fila completa, y la bajada no lo pisa', () async {
    await DatosNube.leer(
      tabla: 't',
      clave: 'registro',
      alcance: 'x',
      consulta: (_) async => [{'registro': 'A', 'awb': 'viejo', 'linea_aerea': 'LH'}],
    );
    final enNube = await DatosNube.guardar(
      tabla: 't',
      clave: 'registro',
      alcance: 'x',
      fila: {'registro': 'A', 'awb': 'editado'},
      copiaLocal: {'registro': 'A', 'awb': 'viejo', 'linea_aerea': 'LH', '_sincronizado': 1},
    );
    expect(enNube, isFalse);
    expect(await DatosNube.pendientes(), 1);

    // Vuelve la red y baja la versión vieja de la nube: el cambio local se conserva.
    final r = await DatosNube.leer(
      tabla: 't',
      clave: 'registro',
      alcance: 'x',
      consulta: (_) async => [{'registro': 'A', 'awb': 'viejo', 'linea_aerea': 'LH'}],
    );
    final a = r.filas.single;
    expect(a['awb'], 'editado');
    expect(a['linea_aerea'], 'LH'); // lo que no se tocó sigue en la copia
    expect(a['_sincronizado'], 0);
    expect(jsonDecode((await filasLocales()).single['datos'] as String), isNot(contains('_sincronizado')));
  });

  test('borrar sin red lo oculta y queda pendiente', () async {
    await DatosNube.leer(tabla: 't', clave: 'registro', alcance: 'x', consulta: (_) async => [{'registro': 'A'}]);
    expect(await DatosNube.borrar(tabla: 't', clave: 'registro', valor: 'A'), isFalse);
    expect(await DatosNube.pendientes(), 1);
    final r = await DatosNube.leer(
      tabla: 't',
      clave: 'registro',
      alcance: 'x',
      consulta: (_) async => [{'registro': 'A'}],
    );
    expect(r.filas, isEmpty);
  });

  test('subir pendientes sin red corta y no pierde nada', () async {
    await DatosNube.guardar(tabla: 't', clave: 'registro', alcance: 'x', fila: {'registro': 'N'});
    await expectLater(DatosNube.subirPendientes({'t': 'registro'}), throwsA(anything));
    expect(await DatosNube.pendientes(), 1);
  });
}
