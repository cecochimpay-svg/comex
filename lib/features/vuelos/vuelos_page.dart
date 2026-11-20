import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/sesion.dart';
import '../../core/auth/sesion_controller.dart';
import '../../core/config.dart';
import '../../core/formato.dart';
import '../../core/nav/catalogo.dart';
import '../../core/red.dart';
import '../../core/sync/servicio_sync.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/avisos.dart';
import '../../widgets/comunes.dart';
import '../../widgets/formulario.dart';
import '../../widgets/listados.dart';
import '../../widgets/resaltar.dart';
import '../home/resumen_datos.dart' show semanaIso;
import '../home/resumen_repo.dart';
import '../modulo/botones_exportar.dart';
import '../modulo/modulo_page.dart';
import 'importar_dialogo.dart';
import 'vuelos_datos.dart';
import 'vuelos_dialogos.dart';
import 'vuelos_exportar.dart';
import 'vuelos_repo.dart';

/// VUELOS: programación de despachos con el formato de la planilla de logística (TCI).
/// COMEX carga y edita sus despachos; ADM / ADMIN ven los de todos (auditoría, sin editar).
class VuelosPage extends StatefulWidget {
  const VuelosPage({super.key, required this.ubicacion});

  final UbicacionPantalla ubicacion;

  @override
  State<VuelosPage> createState() => _VuelosPageState();
}

class _VuelosPageState extends State<VuelosPage> {
  List<Vuelo>? _vuelos;
  bool _offline = false;
  Object? _error;
  FiltrosVuelos _f = const FiltrosVuelos();
  bool _semanaElegida = false;
  final _buscar = TextEditingController();
  final _cambios = CambiosRecientes();
  Timer? _espera;
  ServicioSync? _sync;
  int _versionSync = 0;

  Sesion get _sesion => context.read<SesionController>().actual!;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.read<ServicioSync>();
    if (_sync != s) {
      _sync?.removeListener(_alSincronizar);
      _sync = s..addListener(_alSincronizar);
      _versionSync = s.version;
    }
  }

  @override
  void dispose() {
    _sync?.removeListener(_alSincronizar);
    _espera?.cancel();
    _buscar.dispose();
    super.dispose();
  }

  /// Después de sincronizar se relee (pueden haber subido despachos cargados sin conexión).
  void _alSincronizar() {
    final v = _sync!.version;
    if (v != _versionSync) {
      _versionSync = v;
      _recargar(null);
    }
  }

  Future<void> _cargar() async {
    try {
      final r = await RepoVuelos.cargar(_sesion);
      if (!mounted) return;
      setState(() {
        _vuelos = r.vuelos;
        _offline = r.offline;
        _error = null;
        _elegirSemanaInicial(r.vuelos);
      });
      ResumenVivo.actualizar();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Al abrir: la semana actual si tiene despachos; si no, la más reciente.
  void _elegirSemanaInicial(List<Vuelo> vuelos) {
    if (_semanaElegida) return;
    final semanas = semanasDe(vuelos);
    if (semanas.isEmpty) return;
    final actual = semanaIso(DateTime.now());
    final hay = semanas.any((s) => s.$1 == actual);
    _f = _f.copiar(semana: hay ? actual : semanas.first.$1);
    _semanaElegida = true;
  }

  Future<void> _recargar(String? mensaje, {bool pendiente = false}) async {
    final antes = _firmas();
    await _cargar();
    if (!mounted) return;
    _cambios.comparar(antes, _firmas());
    context.read<ServicioSync>().actualizarPendientes();
    if (mensaje != null) mostrarAviso(context, mensaje, tipo: pendiente ? TipoAviso.aviso : TipoAviso.exito);
  }

  Map<Object, int> _firmas() => firmasDe(_vuelos ?? const <Vuelo>[], (v) => v.f, prefijo: 'vue');

  void _alBuscar(String t) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _f = _f.copiar(texto: t));
    });
  }

  // ── Acciones ──

  Future<void> _nuevo() async {
    final r = await dialogoVuelo(context);
    if (r == null) return;
    await _recargar(r.mensaje, pendiente: r.pendiente);
  }

  /// Planilla Excel del operador: crea los despachos nuevos y actualiza los que ya estaban (por AWB).
  Future<void> _importar() async {
    final r = await importarPlanillaVuelos(context, _vuelos ?? const []);
    if (r == null || !mounted) return;
    final partes = [
      if (r.creados > 0) '${fmtNum(r.creados)} nuevo(s)',
      if (r.actualizados > 0) '${fmtNum(r.actualizados)} actualizado(s)',
    ];
    var mensaje = partes.isEmpty ? 'No se importó ningún despacho.' : 'Planilla importada: ${partes.join(' y ')}.';
    if (r.pendientes > 0) mensaje += ' ${fmtNum(r.pendientes)} sin conexión: se suben al sincronizar.';
    if (r.omitidas.isNotEmpty) mensaje += ' (sin ${r.omitidas.join(', ')}: falta esa columna en Supabase)';
    await _recargar(null);
    if (!mounted) return;
    if (r.errores.isNotEmpty) {
      mostrarAviso(
        context,
        '$mensaje No se pudieron guardar ${r.errores.length}: ${r.errores.take(3).join(' · ')}',
        tipo: TipoAviso.error,
      );
    } else {
      mostrarAviso(context, mensaje, tipo: r.pendientes > 0 ? TipoAviso.aviso : TipoAviso.exito);
    }
  }

  Future<void> _editar(Vuelo v) async {
    final r = await dialogoVuelo(context, edicion: v);
    if (r == null) return;
    await _recargar(r.mensaje, pendiente: r.pendiente);
  }

  Future<void> _borrar(Vuelo v) async {
    final ok = await confirmar(
      context,
      titulo: '¿Eliminar este despacho?',
      mensaje: 'Se borra de la programación para todos (también de COMEX Despachos).',
      detalle: [
        if (v.awb.isNotEmpty) 'AWB ${v.awb}',
        if (v.destino.isNotEmpty) v.destino,
        'Week ${v.semana}',
        '${fmtNum(v.tarimas)} tarimas',
      ].join(' · '),
      textoOk: 'Eliminar',
      peligro: true,
    );
    if (!ok) return;
    try {
      final enNube = await RepoVuelos.borrar(v);
      await _recargar(enNube ? 'Despacho eliminado.' : 'Despacho eliminado sin conexión: se borra al sincronizar.',
          pendiente: !enNube);
    } catch (e) {
      if (mounted) mostrarAviso(context, 'No se pudo eliminar: ${mensajeDe(e)}', tipo: TipoAviso.error);
    }
  }

  // ── Pantalla ──

  @override
  Widget build(BuildContext context) {
    final u = widget.ubicacion;
    final sesion = context.watch<SesionController>().actual!;
    final admin = sesion.esAdministrador;
    final vuelos = _vuelos;
    final lista = vuelos == null ? const <Vuelo>[] : _f.aplicar(vuelos);

    final encabezado = EncabezadoModulo(
      categoria: u.categoria,
      pantalla: u.pantalla,
      acciones: [
        if (vuelos != null)
          BotonesExportar(
            prefijoFolio: 'VUE',
            armar: () async => informeVuelos(lista, _f, todosLosOperadores: admin, operador: sesion.nombre),
          ),
        if (!admin)
          BotonHero(
            icono: Icons.upload_file_rounded,
            texto: 'Importar Excel',
            onTap: vuelos == null ? null : _importar,
          ),
        if (!admin)
          BotonHero(
            icono: Icons.add_rounded,
            texto: 'Registrar despacho',
            principal: true,
            onTap: vuelos == null ? null : _nuevo,
          ),
      ],
    );

    if (vuelos == null) {
      return PaginaContenido(
        anchoMaximo: 1480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            encabezado,
            const SizedBox(height: 20),
            if (_error != null)
              ErrorCarga(error: _error!, reintentar: _cargar, titulo: 'No se pudieron cargar los despachos')
            else
              const CargandoListado(),
          ],
        ),
      );
    }

    final ancha = MediaQuery.sizeOf(context).width >= 1100;
    final filas = _conBandas(lista);

    return ResaltarCambios(
      cambios: _cambios,
      child: PaginaListado(
        anchoMaximo: 1480,
        cabecera: [
          encabezado,
          const SizedBox(height: 6),
          Text(
            admin
                ? 'Auditoría: despachos de todos los operadores en la temporada ${Config.temporada}.'
                : 'Despachos cargados por ${sesion.nombre} en la temporada ${Config.temporada}.',
            style: TextStyle(color: Paleta.tintaSuave, fontSize: 12.5),
          ),
          if (_offline) ...[const SizedBox(height: 12), const _AvisoSinConexion()],
          const SizedBox(height: 16),
          _Indicadores(lista: lista, semana: _f.semana),
          const SizedBox(height: 14),
          _Semanas(
            vuelos: vuelos,
            elegida: _f.semana,
            alElegir: (s) => setState(() => _f = s == null ? _f.copiar(sinSemana: true) : _f.copiar(semana: s)),
          ),
          const SizedBox(height: 12),
          _barraFiltros(vuelos),
          const SizedBox(height: 14),
          if (ancha && lista.isNotEmpty) _EncabezadoTabla(admin: admin),
        ],
        cantidad: filas.length,
        fila: (context, i) {
          final x = filas[i];
          final ultima = i == filas.length - 1;
          if (x is int) return _BandaSemana(semana: x, ancha: ancha, primera: i == 0);
          final v = x as Vuelo;
          return ancha
              ? _FilaVuelo(v: v, admin: admin, ultima: ultima, alEditar: _editar, alBorrar: _borrar)
              : _TarjetaVuelo(v: v, admin: admin, alEditar: _editar, alBorrar: _borrar);
        },
        vacio: EstadoVacio(
          icono: Icons.flight_rounded,
          mensaje: vuelos.isEmpty
              ? (admin
                    ? 'Todavía no hay despachos cargados en la temporada.'
                    : 'Todavía no cargaste despachos. Tocá "Registrar despacho".')
              : 'No hay despachos para los filtros elegidos.',
        ),
        pie: lista.isEmpty ? null : _Pie(lista: lista),
      ),
    );
  }

  /// Con "Todas" se intercala la banda naranja de cada semana, como la planilla.
  List<Object> _conBandas(List<Vuelo> lista) {
    if (_f.semana != null) return lista;
    final ordenada = [...lista]..sort((a, b) => b.semana.compareTo(a.semana));
    final r = <Object>[];
    int? actual;
    for (final v in ordenada) {
      if (v.semana != actual) {
        actual = v.semana;
        r.add(v.semana);
      }
      r.add(v);
    }
    return r;
  }

  Widget _barraFiltros(List<Vuelo> vuelos) {
    final enSemana = _f.semana == null ? vuelos : vuelos.where((v) => v.semana == _f.semana).toList();
    final conteo = <String, int>{};
    for (final v in enSemana) {
      if (v.status.isNotEmpty) conteo[v.status] = (conteo[v.status] ?? 0) + 1;
    }
    final estados = [
      for (final e in estadosDespacho)
        if ((conteo[e.nombre] ?? 0) > 0) e.nombre,
      for (final s in conteo.keys)
        if (!estadosDespacho.any((e) => e.nombre == s)) s,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            controller: _buscar,
            onChanged: _alBuscar,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar AWB, vuelo, destino, CNNE, proforma…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        for (final s in estados)
          _ChipStatus(
            status: s,
            cantidad: conteo[s] ?? 0,
            activo: _f.status == s,
            alTocar: () => setState(() => _f = _f.status == s ? _f.copiar(sinStatus: true) : _f.copiar(status: s)),
          ),
        if (_f.hayFiltros)
          TextButton.icon(
            onPressed: () => setState(() {
              _buscar.clear();
              _f = _f.copiar(sinStatus: true, texto: '');
            }),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Limpiar'),
            style: TextButton.styleFrom(foregroundColor: Paleta.peligro),
          ),
      ],
    );
  }
}

// ───────────────────────────── Cabecera ─────────────────────────────

class _AvisoSinConexion extends StatelessWidget {
  const _AvisoSinConexion();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Paleta.suave(Paleta.oro, 0.10),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Paleta.oro.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 18, color: Paleta.oro),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Sin conexión: se muestran los despachos guardados en este equipo. Lo que cargues se sube al sincronizar.',
            style: TextStyle(fontSize: 12.5, color: Paleta.tinta),
          ),
        ),
      ],
    ),
  );
}

class _Indicadores extends StatelessWidget {
  const _Indicadores({required this.lista, required this.semana});

  final List<Vuelo> lista;
  final int? semana;

  @override
  Widget build(BuildContext context) {
    final tarimas = lista.fold<int>(0, (a, v) => a + v.tarimas);
    final peso = lista.fold<double>(0, (a, v) => a + v.peso);
    final destinos = lista.map((v) => v.destino).where((d) => d.isNotEmpty).toSet();
    final volados = lista.where((v) => v.status == 'VOLADO' || v.status == 'ARRIBADO').length;
    final donde = semana == null ? 'en la temporada' : 'en la week $semana';
    return GrillaAdaptable(
      anchoMinimo: 220,
      maxColumnas: 4,
      espacio: 12,
      children: [
        DatoResumen(
          rotulo: 'Despachos',
          valor: fmtNum(lista.length),
          detalle: donde,
          color: Paleta.azul,
          icono: Icons.flight_takeoff_rounded,
        ),
        DatoResumen(
          rotulo: 'Tarimas',
          valor: fmtNum(tarimas),
          detalle: '${fmtNum(peso)} kg de peso',
          color: Paleta.verde,
          icono: Icons.pallet,
        ),
        DatoResumen(
          rotulo: 'Destinos',
          valor: fmtNum(destinos.length),
          detalle: destinos.isEmpty ? 'sin destinos' : (destinos.toList()..sort()).take(4).join(' · '),
          color: Paleta.violeta,
          icono: Icons.public_rounded,
        ),
        DatoResumen(
          rotulo: 'Volados',
          valor: '${fmtNum(volados)} / ${fmtNum(lista.length)}',
          detalle: 'volados o arribados',
          color: Paleta.exito,
          icono: Icons.flight_land_rounded,
        ),
      ],
    );
  }
}

/// Selector de semanas ("WEEK 46  12"), de la más nueva a la más vieja.
class _Semanas extends StatelessWidget {
  const _Semanas({required this.vuelos, required this.elegida, required this.alElegir});

  final List<Vuelo> vuelos;
  final int? elegida;
  final ValueChanged<int?> alElegir;

  @override
  Widget build(BuildContext context) {
    final semanas = semanasDe(vuelos);
    if (semanas.isEmpty) return const SizedBox.shrink();
    final actual = semanaIso(DateTime.now());
    Widget chip(int? s, String texto, int n, {bool hoy = false}) {
      final activo = elegida == s;
      final color = Paleta.oro;
      return FilterChip(
        selected: activo,
        showCheckmark: false,
        avatar: hoy ? Icon(Icons.today_rounded, size: 15, color: activo ? color : Paleta.tintaSuave) : null,
        label: Text('$texto  ${fmtNum(n)}'),
        labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: activo ? color : Paleta.tinta),
        selectedColor: Paleta.suave(color, 0.14),
        backgroundColor: Paleta.superficie,
        side: BorderSide(color: activo ? color : Paleta.borde),
        shape: const StadiumBorder(),
        onSelected: (_) => alElegir(s),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (s, n, _) in semanas) ...[
            chip(s, 'WEEK $s', n, hoy: s == actual),
            const SizedBox(width: 8),
          ],
          chip(null, 'Todas', vuelos.length),
        ],
      ),
    );
  }
}

class _ChipStatus extends StatelessWidget {
  const _ChipStatus({required this.status, required this.cantidad, required this.activo, required this.alTocar});

  final String status;
  final int cantidad;
  final bool activo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final c = colorStatus(status);
    return FilterChip(
      selected: activo,
      showCheckmark: false,
      avatar: Led(color: c, tamano: 8),
      label: Text('$status  ${fmtNum(cantidad)}'),
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Paleta.tinta),
      selectedColor: Paleta.suave(c, 0.14),
      backgroundColor: Paleta.superficie,
      side: BorderSide(color: activo ? c : Paleta.borde),
      shape: const StadiumBorder(),
      onSelected: (_) => alTocar(),
    );
  }
}

// ───────────────────────────── Tabla (pantallas anchas) ─────────────────────────────

/// Columnas en el orden de la planilla: (flex, título, a la derecha).
List<(int, String, bool)> _columnas(bool admin) => [
  (12, 'AWB', false),
  (10, 'Ingreso TCA', false),
  (7, 'Destino', false),
  (10, 'Ruta', false),
  (8, 'Vuelo', false),
  (8, 'Proforma', false),
  (9, 'ETD', false),
  (8, 'Conex', false),
  (9, 'ETA', false),
  (6, 'Tarimas', true),
  (8, 'Peso', true),
  (8, 'Tarifa', false),
  (11, 'Status', false),
  (12, 'CNNE', false),
  if (admin) (8, 'Operador', false),
];

double _anchoAcciones(bool admin) => admin ? 0 : 84;

class _EncabezadoTabla extends StatelessWidget {
  const _EncabezadoTabla({required this.admin});

  final bool admin;

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: decoFilaTabla(primera: true),
    child: FilaTabla(
      celdas: [for (final (flex, t, der) in _columnas(admin)) (flex, textoEncabezado(t), der)],
      anchoAcciones: _anchoAcciones(admin),
    ),
  );
}

/// Banda naranja "WEEK 46 / 2026", como la planilla de logística.
class _BandaSemana extends StatelessWidget {
  const _BandaSemana({required this.semana, required this.ancha, required this.primera});

  final int semana;
  final bool ancha;
  final bool primera;

  @override
  Widget build(BuildContext context) {
    final naranja = Paleta.dual(0xFFF59E0B, 0xFFB7791F);
    return Container(
      margin: EdgeInsets.only(top: ancha || primera ? 0 : 10, bottom: ancha ? 0 : 8),
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: naranja,
        borderRadius: ancha ? null : BorderRadius.circular(8),
        border: ancha ? Border.symmetric(vertical: BorderSide(color: Paleta.borde)) : null,
      ),
      child: Text(
        'WEEK $semana / ${Config.temporada}',
        style: const TextStyle(color: Color(0xFF1F1300), fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 0.6),
      ),
    );
  }
}

class _FilaVuelo extends StatelessWidget {
  const _FilaVuelo({
    required this.v,
    required this.admin,
    required this.ultima,
    required this.alEditar,
    required this.alBorrar,
  });

  final Vuelo v;
  final bool admin;
  final bool ultima;
  final ValueChanged<Vuelo> alEditar;
  final ValueChanged<Vuelo> alBorrar;

  @override
  Widget build(BuildContext context) {
    final normal = TextStyle(fontSize: 12.5, color: Paleta.tinta);
    final fuerte = normal.copyWith(fontWeight: FontWeight.w700);
    final cifras = normal.copyWith(fontFeatures: cifrasTabulares);
    Widget t(String s, [TextStyle? e]) =>
        Text(s.isEmpty ? '—' : s, maxLines: 1, overflow: TextOverflow.ellipsis, style: e ?? normal);
    Widget fechaHora(String f, String h) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        t(fechaTabla(f), cifras),
        if (h.isNotEmpty) Text(h, style: TextStyle(fontSize: 11, color: Paleta.tintaSuave)),
      ],
    );

    final celdas = <Widget>[
      Row(
        children: [
          if (v.pendiente) ...[const IndicadorSync(sincronizado: 0), const SizedBox(width: 4)],
          Flexible(child: t(v.awb, fuerte)),
        ],
      ),
      t(fechaTabla(v.ingreso), cifras),
      v.destino.isEmpty ? t('') : Pastilla(texto: v.destino, color: Paleta.azul),
      t(v.ruta),
      t(v.vuelo, fuerte),
      t(v.proforma),
      fechaHora(v.etdFecha, v.etdHora),
      v.conex.isEmpty ? t('Directo', TextStyle(fontSize: 12, color: Paleta.tintaTenue)) : t(v.conex, fuerte),
      fechaHora(v.etaFecha, v.etaHora),
      t(fmtNum(v.tarimas), fuerte.copyWith(fontFeatures: cifrasTabulares)),
      t(fmtNum(v.peso), cifras),
      t(v.tarifa),
      StatusLed(status: v.status),
      t(v.cnne, fuerte),
      if (admin) t(v.usuario, TextStyle(fontSize: 12, color: Paleta.tintaSuave)),
    ];
    final cols = _columnas(admin);

    return ContenedorFila(
      clave: claveFila('vue', v.f),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: decoFilaTabla(ultima: ultima),
      child: FilaTabla(
        celdas: [for (var i = 0; i < cols.length; i++) (cols[i].$1, celdas[i], cols[i].$3)],
        anchoAcciones: _anchoAcciones(admin),
        acciones: admin
            ? null
            : Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BotonIconoFila(icono: Icons.edit_rounded, ayuda: 'Editar', onTap: () => alEditar(v)),
                  BotonIconoFila(
                    icono: Icons.delete_outline_rounded,
                    ayuda: 'Eliminar',
                    color: Paleta.peligro,
                    onTap: () => alBorrar(v),
                  ),
                ],
              ),
      ),
    );
  }
}

/// LED encendido con el nombre del status (tabla, tarjetas).
class StatusLed extends StatelessWidget {
  const StatusLed({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return Text('—', style: TextStyle(color: Paleta.tintaTenue));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Led(color: colorStatus(status), tamano: 8),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Paleta.tinta),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── Tarjetas (celular) ─────────────────────────────

class _TarjetaVuelo extends StatelessWidget {
  const _TarjetaVuelo({required this.v, required this.admin, required this.alEditar, required this.alBorrar});

  final Vuelo v;
  final bool admin;
  final ValueChanged<Vuelo> alEditar;
  final ValueChanged<Vuelo> alBorrar;

  @override
  Widget build(BuildContext context) {
    final suave = TextStyle(fontSize: 12, color: Paleta.tintaSuave);
    final fuerte = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Paleta.tinta);
    String fh(String f, String h) => f.isEmpty ? '—' : '${fechaTabla(f)}${h.isEmpty ? '' : ' $h'}';
    final linea = [
      if (v.cnne.isNotEmpty) 'CNNE ${v.cnne}',
      if (v.proforma.isNotEmpty) 'Proforma ${v.proforma}',
      if (admin && v.usuario.isNotEmpty) v.usuario,
    ].join(' · ');
    return Resaltable(
      clave: claveFila('vue', v.f),
      radio: BorderRadius.circular(10),
      margen: const EdgeInsets.only(bottom: 10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: decoTarjeta(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    v.ruta.isEmpty ? (v.destino.isEmpty ? '—' : v.destino) : v.ruta,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Paleta.verdeTitulo),
                  ),
                ),
                if (v.pendiente) ...[const IndicadorSync(sincronizado: 0), const SizedBox(width: 6)],
                StatusLed(status: v.status),
              ],
            ),
            if (linea.isNotEmpty) ...[const SizedBox(height: 4), Text(linea, style: suave)],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('AWB ${v.awb.isEmpty ? '—' : v.awb}', style: fuerte)),
                Text('Vuelo ${v.vuelo.isEmpty ? '—' : v.vuelo}', style: fuerte),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Paleta.superficieSuave, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ETD ${fh(v.etdFecha, v.etdHora)}  →  ETA ${fh(v.etaFecha, v.etaHora)}', style: fuerte),
                  const SizedBox(height: 2),
                  Text(
                    '${v.conex.isEmpty ? 'Directo' : 'Conex ${v.conex}'}'
                    '${v.ingreso.isEmpty ? '' : ' · Ingreso TCA ${fechaTabla(v.ingreso)}'}',
                    style: suave,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.pallet, size: 16, color: Paleta.verde),
                const SizedBox(width: 6),
                Expanded(child: Text('${fmtNum(v.tarimas)} tarimas · ${fmtNum(v.peso)} kg', style: fuerte)),
                if (v.tarifa.isNotEmpty) Pastilla(texto: v.tarifa, color: Paleta.oro),
                if (!admin) ...[
                  BotonIconoFila(icono: Icons.edit_rounded, ayuda: 'Editar', onTap: () => alEditar(v)),
                  BotonIconoFila(
                    icono: Icons.delete_outline_rounded,
                    ayuda: 'Eliminar',
                    color: Paleta.peligro,
                    onTap: () => alBorrar(v),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie({required this.lista});

  final List<Vuelo> lista;

  @override
  Widget build(BuildContext context) {
    final tarimas = lista.fold<int>(0, (a, v) => a + v.tarimas);
    final peso = lista.fold<double>(0, (a, v) => a + v.peso);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        '${fmtNum(lista.length)} despacho(s) · ${fmtNum(tarimas)} tarimas · ${fmtNum(peso)} kg',
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Paleta.tintaSuave),
      ),
    );
  }
}
