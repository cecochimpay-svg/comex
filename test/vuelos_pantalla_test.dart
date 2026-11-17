import 'dart:convert';

import 'package:comex/core/auth/auth_servicio.dart';
import 'package:comex/core/auth/sesion_controller.dart';
import 'package:comex/core/datos/datos_nube.dart';
import 'package:comex/core/db/base_local.dart';
import 'package:comex/core/nav/catalogo.dart';
import 'package:comex/core/preferencias.dart';
import 'package:comex/core/sync/servicio_sync.dart';
import 'package:comex/core/tema/tema.dart';
import 'package:comex/features/vuelos/vuelos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dibuja la pantalla de Vuelos sin internet, con despachos de ejemplo en la copia local, en una
/// pantalla ancha (tabla) y una de celular (tarjetas). Falla si algo se desborda.
/// Con --update-goldens deja las capturas en test/capturas/ para mirarlas.
void main() {
  late Database db;
  final nube = SupabaseClient('http://127.0.0.1:9', 'clave-de-prueba');

  setUpAll(() async {
    sqfliteFfiInit();
    // Fuente real (en vez de los cuadraditos de los tests) para que las capturas se puedan leer.
    final fuente = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fuentes/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fuentes/NotoSans-Bold.ttf'));
    await fuente.load();
  });

  Future<Widget> armar({required String usuario, required String rol}) async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    await BaseLocal.usar(db);
    DatosNube.cliente = () => nube;

    await db.insert('sesion_activa', {
      'id': 1,
      'usuario_id': 1,
      'nombre_usuario': usuario,
      'token': 'x',
      'fecha_inicio': DateTime.now().toUtc().toIso8601String(),
      'rol': rol,
      'correo': '$usuario@comex.cecoargentina.com',
    });
    final alcance = rol == 'ADM' ? '2026|*' : '2026|${usuario.toLowerCase()}';
    final ejemplos = [
      {'registro': 'A1', 'semana': 46, 'temporada': 2026, 'awb': '020-03123046', 'ingreso': '2026-11-10', 'destino': 'PVG', 'ruta': 'EZE-FRA-PVG', 'vuelo': 'LH 511', 'proforma': 'PF-1201', 'fecha_etd1': '2026-11-11', 'hora_etd1': '21:40', 'vuelo_cnx': 'LH8400', 'fecha_eta_1': '2026-11-13', 'hora_eta1': '06:10', 'pcs': 6, 'kilos': 3900, 'tarifa_kg': 'USD 3,10', 'status': 'VOLADO', 'consignatario': 'Shanghai Fresh Co.', 'usuario': 'juan'},
      {'registro': 'A2', 'semana': 46, 'temporada': 2026, 'awb': '045-22004511', 'ingreso': '2026-11-12', 'destino': 'MIA', 'ruta': 'EZE-MIA', 'vuelo': 'LA 500', 'proforma': 'PF-1202', 'fecha_etd1': '2026-11-13', 'hora_etd1': '23:55', 'pcs': 4, 'kilos': 2600, 'tarifa_kg': 'USD 2,45', 'status': 'EN TCA', 'consignatario': 'Miami Produce LLC', 'usuario': 'juan'},
      {'registro': 'A3', 'semana': 46, 'temporada': 2026, 'destino': 'MAD', 'proforma': 'PF-1203', 'pcs': 5, 'kilos': 3250, 'status': 'PROGRAMADO', 'consignatario': 'Frutas del Sur SL', 'usuario': 'juan'},
      {'registro': 'B1', 'semana': 45, 'temporada': 2026, 'awb': '020-03120001', 'destino': 'CAN', 'origen': 'EZE', 'vuelo': 'LH 511', 'fecha_etd1': '2026-11-04', 'pcs': 8, 'kilos': 5200, 'status': 'ARRIBADO', 'consignatario': 'Guangzhou Fruit', 'usuario': 'juan'},
    ];
    for (final e in ejemplos) {
      await db.insert('filas', {
        'tabla': 'logistitcas_temporada',
        'clave': e['registro'],
        'alcance': alcance,
        'datos': jsonEncode(e),
        'sincronizado': e['registro'] == 'A3' ? 0 : 1,
      });
    }

    SharedPreferences.setMockInitialValues({});
    final prefs = await Preferencias.cargar();
    final sesion = SesionController(AuthServicio(nube));
    await sesion.restaurar();
    final sync = ServicioSync(nube, prefs);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sesion),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider.value(value: sync),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: temaComex(),
        home: Scaffold(body: VuelosPage(ubicacion: indicePantallas['VUELOS']!)),
      ),
    );
  }

  Future<void> dibujar(WidgetTester tester, Size tamano, Widget app) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(app);
      // La lectura (nube inalcanzable -> copia local) es asincrónica de verdad.
      for (var i = 0; i < 100 && find.text('AWB').evaluate().isEmpty && find.textContaining('020-').evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('COMEX en pantalla ancha: tabla con las columnas de la planilla y LED de status', (tester) async {
    final app = (await tester.runAsync(() => armar(usuario: 'juan', rol: 'COMEX')))!;
    await dibujar(tester, const Size(1600, 1000), app);

    expect(find.text('Registrar despacho'), findsOneWidget);
    expect(find.textContaining('Sin conexión'), findsOneWidget);
    for (final t in ['AWB', 'INGRESO TCA', 'DESTINO', 'RUTA', 'VUELO', 'PROFORMA', 'ETD', 'CONEX', 'ETA', 'TARIMAS', 'PESO', 'TARIFA', 'STATUS', 'CNNE']) {
      expect(find.text(t), findsWidgets, reason: 'falta la columna $t');
    }
    expect(find.text('EZE-FRA-PVG'), findsOneWidget);
    expect(find.text('Shanghai Fresh Co.'), findsOneWidget);
    // Abre en la semana actual (46): el de la semana 45 no se ve.
    expect(find.text('Guangzhou Fruit'), findsNothing);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('capturas/vuelos_ancha.png'));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });

  testWidgets('ADM en celular: tarjetas, sin botón de alta, todas las semanas con banda', (tester) async {
    final app = (await tester.runAsync(() => armar(usuario: 'ADMIN', rol: 'ADM')))!;
    await dibujar(tester, const Size(400, 1400), app);

    expect(find.text('Registrar despacho'), findsNothing);
    await tester.ensureVisible(find.textContaining('Todas'));
    await tester.pump();
    await tester.tap(find.textContaining('Todas'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('WEEK 46 / 2026'), findsOneWidget);
    expect(find.text('WEEK 45 / 2026'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('capturas/vuelos_celular.png'));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
