import 'package:comex/features/home/resumen_datos.dart';
import 'package:comex/features/vuelos/vuelos_datos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('semana de la planilla', () {
    test('ISO: 12/11/2026 es la week 46 (como la planilla de TCI)', () {
      expect(semanaIso(DateTime(2026, 11, 12)), 46);
    });
    test('ISO: los primeros días de enero pueden ser de la semana 53 del año anterior', () {
      expect(semanaIso(DateTime(2027, 1, 1)), 53);
      expect(semanaIso(DateTime(2026, 1, 1)), 1);
    });
    test('sale de la ETD; sin ETD, del ingreso TCA', () {
      expect(semanaDeDespacho(etd: '2026-11-12', ingreso: '2026-11-02'), 46);
      expect(semanaDeDespacho(ingreso: '2026-11-02'), 45);
    });
  });

  group('Vuelo', () {
    test('ETA: en registros viejos con conexión se muestra la del tramo 2', () {
      final v = Vuelo({
        'fecha_eta_1': '2026-11-03',
        'hora_eta1': '10:00:00',
        'fecha_eta_2': '2026-11-05T00:00:00',
        'hora_eta2': '08:15:00',
      });
      expect(v.etaEnTramo2, isTrue);
      expect(v.etaFecha, '2026-11-05');
      expect(v.etaHora, '08:15');
    });
    test('ETA: sin tramo 2 se usa la del tramo 1', () {
      final v = Vuelo({'fecha_eta_1': '2026-11-03', 'hora_eta1': '10:00'});
      expect(v.etaEnTramo2, isFalse);
      expect(v.etaFecha, '2026-11-03');
    });
    test('ruta: la cargada; si no hay, origen-destino', () {
      expect(Vuelo({'ruta': 'eze-fra-pvg', 'origen': 'EZE', 'destino': 'PVG'}).ruta, 'EZE-FRA-PVG');
      expect(Vuelo({'origen': 'eze', 'destino': 'pvg'}).ruta, 'EZE-PVG');
      expect(Vuelo({'destino': 'MIA'}).ruta, 'MIA');
    });
    test('pendiente cuando la copia local no subió', () {
      expect(Vuelo({'_sincronizado': 0}).pendiente, isTrue);
      expect(Vuelo({'_sincronizado': 1}).pendiente, isFalse);
      expect(Vuelo({}).pendiente, isFalse);
    });
  });

  group('filtros', () {
    final vuelos = [
      Vuelo({'registro': 'A', 'semana': 46, 'awb': '020-1', 'status': 'VOLADO', 'fecha_etd1': '2026-11-13', 'consignatario': 'Frutas SL'}),
      Vuelo({'registro': 'B', 'semana': 46, 'awb': '020-2', 'status': 'programado', 'fecha_etd1': '2026-11-11'}),
      Vuelo({'registro': 'C', 'semana': 46, 'awb': '020-3'}),
      Vuelo({'registro': 'D', 'semana': 45, 'awb': '020-4', 'status': 'VOLADO'}),
    ];

    test('por semana, ordenado por ETD (sin ETD al final)', () {
      final r = const FiltrosVuelos(semana: 46).aplicar(vuelos);
      expect(r.map((v) => v.registro), ['B', 'A', 'C']);
    });
    test('por status (sin importar mayúsculas) y texto', () {
      expect(const FiltrosVuelos(status: 'PROGRAMADO').aplicar(vuelos).map((v) => v.registro), ['B']);
      expect(const FiltrosVuelos(texto: 'frutas').aplicar(vuelos).map((v) => v.registro), ['A']);
    });
    test('semanas de la más nueva a la más vieja con cantidades', () {
      expect(semanasDe(vuelos).map((s) => (s.$1, s.$2)), [(46, 3), (45, 1)]);
    });
    test('copiar puede sacar la semana o el status', () {
      const f = FiltrosVuelos(semana: 46, status: 'VOLADO', texto: 'x');
      expect(f.copiar(sinSemana: true).semana, isNull);
      expect(f.copiar(sinStatus: true).status, isNull);
      expect(f.copiar(texto: '').hayFiltros, isTrue);
    });
  });

  test('tarifa se guarda como "USD x" y vacía queda null', () {
    expect(normalizarTarifa('3,10'), 'USD 3,10');
    expect(normalizarTarifa('usd 3,10'), 'USD 3,10');
    expect(normalizarTarifa('  '), isNull);
  });

  test('fecha corta de la tabla', () {
    expect(fechaTabla('2026-11-12'), '12/11');
    expect(fechaTabla(''), '—');
  });
}
