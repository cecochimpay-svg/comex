import 'package:comex/features/programa/programa_datos.dart';
import 'package:flutter_test/flutter_test.dart';

DatosPrograma _datos({List<Map<String, Object?>> renglones = const [], List<Map<String, Object?>> vuelos = const []}) =>
    DatosPrograma(
      vuelos: vuelos,
      proyecciones: const {},
      renglones: renglones,
      clientes: const {
        'CLI A': [OpcionConsignatario('CNNE 1', 'PVG'), OpcionConsignatario('CNNE 2', 'MIA')],
      },
      marcas: const [],
      offline: false,
    );

void main() {
  test('rango de pallets como en Electron', () {
    expect(parsearRangoPallets('101, 102'), ['101', '102']);
    expect(parsearRangoPallets('200-203'), ['200', '201', '202', '203']);
    expect(parsearRangoPallets('PL-A, 5-3'), ['PL-A', '5-3']);
  });

  test('fechas y formatos del PDF', () {
    expect(fechas11Dias('2026-12-28').last, '2027-01-07');
    expect(semanaDeFecha('2026-11-12'), 46);
    expect(formatearFecha('2026-11-12T08:30'), '12/11/2026');
    expect(fechaHoraCorta('2026-11-12 08:30:00'), '12/11 08:30');
    expect(fechaHoraCorta('S/D'), 'S/D');
    expect(siguienteCamion(['CAMIÓN 01', 'CAMIÓN 02']), 'CAMIÓN 03');
  });

  test('vuelos del día, cupo y agrupado', () {
    final d = _datos(
      vuelos: [
        {'registro': 'A', 'fecha': '2026-11-10', 'fecha_etd1': '2026-11-12', 'vuelo': 'LH1', 'pcs': 10},
        {'registro': 'B', 'fecha': '2026-11-13', 'vuelo': 'LH2', 'pcs': 5},
      ],
      renglones: [
        {'id': 1, 'programa_nro': 'P1', 'fecha': '2026-11-12', 'vuelo': 'LH1', 'cantidad': 3, 'cliente': 'CLI A', 'destino': 'MIA'},
        {'id': 2, 'programa_nro': 'P1', 'fecha': '2026-11-12', 'vuelo': 'LH1', 'cantidad': 2, 'cliente': 'CLI A', 'destino': 'MIA'},
        {'id': 3, 'programa_nro': 'P2', 'fecha': '2026-11-12', 'vuelo': 'LH1', 'cantidad': 4},
      ],
    );
    expect(d.vuelosDelDia('2026-11-12').map((v) => v['registro']), ['A']);
    expect(d.palletsGuardadosEnVuelo('LH1', '2026-11-12'), 9);
    expect(d.palletsGuardadosEnVuelo('LH1', '2026-11-12', excluirPrograma: 'P1'), 4);
    expect(d.programas.map((p) => (p.nro, p.pallets)), [('P1', 5), ('P2', 4)]);
    expect(d.consignatarioDe(d.renglones.first), 'CNNE 2');
    expect(d.nroEnUso('P1'), isTrue);
    expect(d.nroEnUso('P1', salvo: 'P1'), isFalse);

    final bloques = bloquesDesdeRenglones(d, d.renglonesDe('P1'), conservarIds: true);
    expect(bloques.length, 1);
    expect(bloques.first.total, 5);
    final filas = renglonesAGuardar(
      bloques: bloques,
      nro: 'P1',
      fecha: '2026-11-12',
      salidaEmpaque: '2026-11-12T08:00',
      usuario: 'juan',
      edicion: true,
    );
    expect(filas.map((f) => f['id']), [1, 2]);
    expect(filas.first['semana'], 46);
    expect(filas.first['consignatario'], 'CNNE 2');
  });
}
