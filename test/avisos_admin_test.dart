import 'package:comex/core/auth/sesion.dart';
import 'package:comex/core/avisos/avisos_admin.dart';
import 'package:comex/core/tema/tema.dart';
import 'package:comex/features/shell/panel_avisos.dart';
import 'package:comex/features/vuelos/vuelos_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Fuente en memoria: guarda los avisos, deja mandar "tiempo real" y anota qué se cerró.
class FuenteFalsa implements FuenteAvisos {
  FuenteFalsa(this.filas);

  final List<Map<String, dynamic>> filas;
  final cerrados = <int>[];
  bool sinConexion = false;
  void Function(Map<String, dynamic>)? _nuevo;
  void Function(int)? _cerrado;
  int escuchando = 0;

  @override
  Future<List<Map<String, dynamic>>> abiertos() async {
    if (sinConexion) throw Exception('sin conexión');
    return [for (final f in filas) if (!cerrados.contains(f['id'])) f];
  }

  @override
  void Function() escuchar({
    required void Function(Map<String, dynamic>) nuevo,
    required void Function(int) cerrado,
  }) {
    _nuevo = nuevo;
    _cerrado = cerrado;
    escuchando++;
    return () => escuchando--;
  }

  @override
  Future<void> cerrar(List<int> ids, String quien) async {
    if (sinConexion) throw Exception('sin conexión');
    cerrados.addAll(ids);
  }

  void llega(Map<String, dynamic> f) {
    filas.add(f);
    _nuevo?.call(f);
  }

  void cierraOtroAdm(int id) {
    cerrados.add(id);
    _cerrado?.call(id);
  }
}

Map<String, dynamic> aviso(int id, String usuario, String accion, {String? fecha, Map<String, dynamic>? cambios}) => {
  'id': id,
  'fecha': fecha ?? '2026-11-19T15:0$id:00Z',
  'usuario': usuario,
  'accion': accion,
  'awb': '071-6326681$id',
  'destino': 'can',
  'vuelo': 'ET507',
  'semana': 47,
  'cambios': cambios,
};

const adm = Sesion(usuarioId: 1, nombre: 'ADMIN', rol: 'ADM', correo: 'admin@comex', offline: false);
const externo = Sesion(usuarioId: 2, nombre: 'mcurcio@jetcargo.com.ar', rol: 'EXTERNO', correo: 'x', offline: false);

void main() {
  test('sólo el ADM escucha avisos; al salir se apagan', () async {
    final fuente = FuenteFalsa([aviso(1, 'mcurcio@jetcargo.com.ar', 'ALTA')]);
    final avisos = AvisosAdmin(fuente, revisarCada: const Duration(hours: 1));

    await avisos.seguir(externo);
    expect(avisos.total, 0);
    expect(fuente.escuchando, 0);
    expect(externo.esAdministrador, isFalse);
    expect(externo.rolEtiqueta, 'Operador externo');

    await avisos.seguir(adm);
    expect(avisos.total, 1);
    expect(fuente.escuchando, 1);

    await avisos.seguir(null);
    expect(avisos.total, 0);
    expect(fuente.escuchando, 0);
    avisos.dispose();
  });

  test('agrupa por usuario, recibe en tiempo real y cierra en la nube', () async {
    final fuente = FuenteFalsa([
      aviso(1, 'mcurcio@jetcargo.com.ar', 'ALTA'),
      aviso(2, 'mmendy@trust-cargo.com', 'BAJA'),
      aviso(3, 'mcurcio@jetcargo.com.ar', 'EDICION', cambios: {'status': ['PROGRAMADO', 'VOLADO']}),
    ]);
    final avisos = AvisosAdmin(fuente, revisarCada: const Duration(hours: 1));
    await avisos.seguir(adm);

    var g = avisos.grupos;
    expect(g.map((x) => x.usuario), ['mcurcio@jetcargo.com.ar', 'mmendy@trust-cargo.com']);
    expect(g.first.cuantos('ALTA'), 1);
    expect(g.first.avisos.first.cambios['status'], ('PROGRAMADO', 'VOLADO'));
    expect(g.first.avisos.first.destino, 'CAN');

    fuente.llega(aviso(4, 'mmendy@trust-cargo.com', 'EDICION', fecha: '2026-11-19T16:00:00Z'));
    g = avisos.grupos;
    expect(g.first.usuario, 'mmendy@trust-cargo.com', reason: 'el grupo con el cambio más nuevo va primero');
    expect(avisos.total, 4);

    await avisos.cerrarGrupo('mmendy@trust-cargo.com');
    expect(fuente.cerrados, unorderedEquals([2, 4]));
    expect(avisos.grupos.single.usuario, 'mcurcio@jetcargo.com.ar');

    fuente.cierraOtroAdm(1);
    expect(avisos.total, 1);
    avisos.dispose();
  });

  test('cerrados sin conexión no vuelven a aparecer y se marcan después', () async {
    final fuente = FuenteFalsa([aviso(1, 'mcurcio@jetcargo.com.ar', 'ALTA')]);
    final avisos = AvisosAdmin(fuente, revisarCada: const Duration(hours: 1));
    await avisos.seguir(adm);

    fuente.sinConexion = true;
    await avisos.cerrarTodos();
    expect(avisos.total, 0);
    expect(fuente.cerrados, isEmpty);

    fuente.sinConexion = false;
    await avisos.recargar();
    expect(fuente.cerrados, [1]);
    expect(avisos.total, 0);
    avisos.dispose();
  });

  testWidgets('el panel muestra la tarjeta y la X la cierra', (tester) async {
    final fuente = FuenteFalsa([
      aviso(1, 'mcurcio@jetcargo.com.ar', 'EDICION', cambios: {'status': ['PROGRAMADO', 'VOLADO'], 'pcs': [5, 6]}),
      aviso(2, 'mcurcio@jetcargo.com.ar', 'BAJA'),
    ]);
    final avisos = AvisosAdmin(fuente, revisarCada: const Duration(hours: 1));
    await tester.runAsync(() => avisos.seguir(adm));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: avisos,
        child: MaterialApp(theme: temaComex(), home: const Scaffold(body: Align(alignment: Alignment.topRight, child: PanelAvisos()))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('mcurcio@jetcargo.com.ar'), findsOneWidget);
    expect(find.text('Status: PROGRAMADO → VOLADO'), findsOneWidget);
    expect(find.text('Tarimas: 5 → 6'), findsOneWidget);
    expect(find.text('1 baja(s)'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar aviso'));
    await tester.pumpAndSettle();
    expect(find.text('mcurcio@jetcargo.com.ar'), findsNothing);
    expect(fuente.cerrados, unorderedEquals([1, 2]));
    avisos.dispose();
  });

  test('textos de tiempo', () {
    final ahora = DateTime(2026, 11, 19, 15, 30);
    expect(haceCuanto(DateTime(2026, 11, 19, 15, 29, 40), ahora: ahora), 'recién');
    expect(haceCuanto(DateTime(2026, 11, 19, 15, 10), ahora: ahora), 'hace 20 min');
    expect(haceCuanto(DateTime(2026, 11, 18, 9, 5), ahora: ahora), 'ayer 09:05');
    expect(horaCorta(DateTime(2026, 11, 2, 8, 0), ahora: ahora), '02/11 08:00');
  });

  test('el filtro por usuario no usa comodines', () {
    expect(RepoVuelos.patronExacto('j_lopez'), r'j\_lopez');
    expect(RepoVuelos.patronExacto('100%'), r'100\%');
    expect(RepoVuelos.patronExacto('mcurcio@jetcargo.com.ar'), 'mcurcio@jetcargo.com.ar');
  });
}
