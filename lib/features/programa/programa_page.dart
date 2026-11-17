import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/sesion_controller.dart';
import '../../core/db/filas.dart';
import '../../core/formato.dart';
import '../../core/nav/catalogo.dart';
import '../../core/red.dart';
import '../../core/sync/servicio_sync.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/avisos.dart';
import '../../widgets/comunes.dart';
import '../../widgets/listados.dart';
import '../home/resumen_repo.dart';
import '../modulo/modulo_page.dart';
import 'programa_datos.dart';
import 'programa_dialogos.dart';
import 'programa_repo.dart';

/// PROGRAMA: Programa de trabajo (programa/programa_trab.html de la versión Electron).
///   1. Proyección operativa: kilos por concepto para 11 días, cruzados con los vuelos cargados.
///   2. Programa de trabajo y despachos: programas por camión / cliente / vuelo con sus calibres.
class ProgramaPage extends StatefulWidget {
  const ProgramaPage({super.key, required this.ubicacion});

  final UbicacionPantalla ubicacion;

  @override
  State<ProgramaPage> createState() => _ProgramaPageState();
}

class _ProgramaPageState extends State<ProgramaPage> {
  DatosPrograma? _datos;
  Object? _error;
  bool _vistaPrograma = false;
  bool _guardandoProy = false;

  List<String> _fechas = fechas11Dias(isoDe(DateTime.now()));
  final _celdas = <String, TextEditingController>{};

  ServicioSync? _sync;
  int _version = 0;

  String get _usuario => context.read<SesionController>().actual?.nombre ?? '';

  @override
  void initState() {
    super.initState();
    _sync = context.read<ServicioSync>()..addListener(_alSincronizar);
    _version = _sync!.version;
    _cargar();
  }

  @override
  void dispose() {
    _sync?.removeListener(_alSincronizar);
    for (final c in _celdas.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Después de una sincronización se vuelve a leer todo.
  void _alSincronizar() {
    final s = _sync;
    if (s == null || s.version == _version) return;
    _version = s.version;
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final d = await RepoPrograma.cargar(_usuario);
      if (!mounted) return;
      setState(() {
        _datos = d;
        _error = null;
        _armarCeldas();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Campos de la grilla de 11 días con lo guardado (al cambiar la fecha se descarta lo no guardado).
  void _armarCeldas() {
    for (final c in _celdas.values) {
      c.dispose();
    }
    _celdas.clear();
    final d = _datos;
    for (final f in _fechas) {
      final p = d?.proyecciones[f];
      for (final (campo, _) in conceptosProyeccion) {
        final v = p?['${campo}_kg'];
        _celdas['$f|$campo'] = TextEditingController(text: v == null || txt(v).isEmpty ? '' : numEntrada(numDe(v)));
      }
    }
  }

  void _cambiarDesde(DateTime d) => setState(() {
    _fechas = fechas11Dias(isoDe(d));
    _armarCeldas();
  });

  Future<void> _trasCambio(String mensaje, {bool enNube = true}) async {
    await _cargar();
    if (!mounted) return;
    context.read<ServicioSync>().actualizarPendientes();
    ResumenVivo.actualizar();
    mostrarAviso(context, mensaje, tipo: enNube ? TipoAviso.exito : TipoAviso.aviso);
  }

  // ── Proyección ──

  Future<void> _guardarYContinuar() async {
    final d = _datos;
    if (d == null) return;
    final valores = {
      for (final f in _fechas)
        f: {for (final (c, _) in conceptosProyeccion) c: leerNum(_celdas['$f|$c']?.text ?? '') ?? 0.0},
    };
    setState(() => _guardandoProy = true);
    try {
      final enNube = await RepoPrograma.guardarProyeccion(datos: d, usuario: _usuario, valores: valores);
      if (!mounted) return;
      setState(() => _vistaPrograma = true);
      await _trasCambio(
        enNube
            ? 'Proyección guardada con éxito.'
            : 'Proyección guardada en este equipo. Sin conexión: se subirá al sincronizar.',
        enNube: enNube,
      );
    } catch (e) {
      if (mounted) mostrarAviso(context, 'Error guardando proyección: ${mensajeDe(e)}', tipo: TipoAviso.error);
    } finally {
      if (mounted) setState(() => _guardandoProy = false);
    }
  }

  // ── Programas ──

  Future<void> _abrirEditor(AperturaPrograma apertura) async {
    final d = _datos;
    if (d == null) return;
    final r = await dialogoPrograma(context, d, apertura, usuario: _usuario);
    if (r != null) await _trasCambio(r.mensaje, enNube: r.enNube);
  }

  void _nuevo() {
    final hoy = _fechas.first;
    _abrirEditor(
      AperturaPrograma(modo: ModoPrograma.nuevo, fecha: hoy, salida: '${hoy}T08:00', nro: generarNroPrograma()),
    );
  }

  void _editar(ProgramaAgrupado p) {
    final d = _datos!;
    final r0 = p.renglones.first;
    _abrirEditor(AperturaPrograma(
      modo: ModoPrograma.editar,
      fecha: soloFecha(r0['fecha']),
      salida: aFechaHoraLocal(r0['salida_empaque']),
      nro: p.nro,
      bloques: bloquesDesdeRenglones(d, p.renglones, conservarIds: true),
      programaOriginal: p.nro,
      originales: p.renglones,
      usuarioOriginal: txt(r0['usuario']).isEmpty ? null : txt(r0['usuario']),
    ));
  }

  void _copiar(ProgramaAgrupado p) {
    final d = _datos!;
    final hoy = _fechas.first;
    final partes = aFechaHoraLocal(p.renglones.first['salida_empaque']).split('T');
    final hora = partes.length > 1 && partes[1].isNotEmpty ? partes[1] : '08:00';
    _abrirEditor(AperturaPrograma(
      modo: ModoPrograma.copiar,
      fecha: hoy,
      salida: '${hoy}T$hora',
      nro: generarNroPrograma(),
      bloques: bloquesDesdeRenglones(d, p.renglones, conservarIds: false),
      programaOriginal: p.nro,
      avisoInicial: 'Copia lista: ajustá la fecha, elegí el vuelo y usá "Aplicar este vuelo a todos los bloques".',
    ));
  }

  Future<void> _verDetalle(ProgramaAgrupado p) async {
    final accion = await dialogoDetallePrograma(context, _datos!, p);
    if (!mounted) return;
    switch (accion) {
      case AccionDetalle.editar:
        _editar(p);
      case AccionDetalle.copiar:
        _copiar(p);
      case null:
        break;
    }
  }

  // ── Pantalla ──

  @override
  Widget build(BuildContext context) {
    final u = widget.ubicacion;
    final d = _datos;
    final encabezado = EncabezadoModulo(
      categoria: u.categoria,
      pantalla: u.pantalla,
      acciones: [
        BotonVolver(categoria: u.categoria),
        BotonHero(icono: Icons.add_rounded, texto: 'Nuevo programa', principal: true, onTap: d == null ? null : _nuevo),
      ],
    );

    if (d == null) {
      return PaginaContenido(
        anchoMaximo: 1320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            encabezado,
            const SizedBox(height: 20),
            if (_error != null)
              ErrorCarga(error: _error!, reintentar: _cargar, titulo: 'No se pudo cargar el programa de trabajo')
            else
              const CargandoListado(indicadores: 0),
          ],
        ),
      );
    }

    final cabecera = <Widget>[
      encabezado,
      const SizedBox(height: 18),
      Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Pestanas(programa: _vistaPrograma, alCambiar: (v) => setState(() => _vistaPrograma = v)),
          if (d.offline)
            Pastilla(texto: 'Sin conexión: copia guardada en este equipo', color: Paleta.oro, icono: Icons.cloud_off_rounded),
        ],
      ),
      const SizedBox(height: 16),
    ];

    if (!_vistaPrograma) {
      return PaginaContenido(
        anchoMaximo: 1400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...cabecera,
            _VistaProyeccion(
              datos: d,
              fechas: _fechas,
              celdas: _celdas,
              guardando: _guardandoProy,
              alCambiarDesde: _cambiarDesde,
              alGuardar: _guardarYContinuar,
            ),
          ],
        ),
      );
    }

    final ancha = MediaQuery.sizeOf(context).width >= 1000;
    final programas = d.programas;
    return PaginaListado(
      anchoMaximo: 1400,
      cabecera: [
        ...cabecera,
        _BannerProyeccion(datos: d, fechas: _fechas),
        const SizedBox(height: 16),
        Text(
          'Programas y despachos consolidados',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Paleta.verdeTitulo),
        ),
        Text(
          'Un renglón por programa, con el total de pallets. Tocá un programa para ver camiones, pallets y calibres.',
          style: TextStyle(fontSize: 12.5, color: Paleta.tintaSuave),
        ),
        const SizedBox(height: 10),
        if (ancha && programas.isNotEmpty) const _EncabezadoProgramas(),
      ],
      cantidad: programas.length,
      fila: (context, i) {
        final p = programas[i];
        return ancha
            ? _FilaPrograma(
                p: p,
                ultima: i == programas.length - 1,
                alAbrir: _verDetalle,
                alEditar: _editar,
                alCopiar: _copiar,
              )
            : _TarjetaPrograma(p: p, alAbrir: _verDetalle, alEditar: _editar, alCopiar: _copiar);
      },
      vacio: const EstadoVacio(mensaje: 'No hay programas confeccionados aún.', icono: Icons.event_note_rounded),
      pie: programas.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '${fmtNum(programas.length)} programa(s) · ${fmtNum(programas.fold<int>(0, (s, p) => s + p.pallets))} pallets',
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w700, color: Paleta.tintaSuave),
              ),
            ),
    );
  }
}

// ───────────────────────────── Cabecera ─────────────────────────────

class _Pestanas extends StatelessWidget {
  const _Pestanas({required this.programa, required this.alCambiar});

  final bool programa;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
    showSelectedIcon: false,
    style: SegmentedButton.styleFrom(
      selectedBackgroundColor: Paleta.verde,
      selectedForegroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
    ),
    segments: const [
      ButtonSegment(value: false, icon: Icon(Icons.insights_rounded, size: 17), label: Text('1 · Proyección operativa')),
      ButtonSegment(value: true, icon: Icon(Icons.local_shipping_rounded, size: 17), label: Text('2 · Programa y despachos')),
    ],
    selected: {programa},
    onSelectionChanged: (s) => alCambiar(s.first),
  );
}

Color _colorConcepto(String c) => switch (c) {
  'cosecha' => Paleta.verde,
  'inspeccion' => Paleta.azul,
  'carga' => Paleta.oro,
  'ezeiza' => Paleta.violeta,
  _ => Paleta.terracota,
};

Widget _punto(Color c) => Container(
  width: 8,
  height: 8,
  margin: const EdgeInsets.only(right: 7),
  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
);

// ───────────────────────────── Solapa 1: Proyección ─────────────────────────────

class _VistaProyeccion extends StatelessWidget {
  const _VistaProyeccion({
    required this.datos,
    required this.fechas,
    required this.celdas,
    required this.guardando,
    required this.alCambiarDesde,
    required this.alGuardar,
  });

  final DatosPrograma datos;
  final List<String> fechas;
  final Map<String, TextEditingController> celdas;
  final bool guardando;
  final ValueChanged<DateTime> alCambiarDesde;
  final VoidCallback alGuardar;

  static const _anchoConcepto = 150.0;
  static const _anchoDia = 112.0;

  @override
  Widget build(BuildContext context) {
    Widget celdaEncabezado(String f) => SizedBox(
      width: _anchoDia,
      child: Column(
        children: [
          Text(
            diaSemana(f).toUpperCase(),
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Paleta.tintaSuave, letterSpacing: 0.4),
          ),
          Text(diaMes(f), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Paleta.tinta)),
        ],
      ),
    );
    Widget concepto(String texto, Color color) => SizedBox(
      width: _anchoConcepto,
      child: Row(
        children: [
          _punto(color),
          Flexible(
            child: Text(texto, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Paleta.tinta)),
          ),
        ],
      ),
    );
    Widget fila(Widget primera, List<Widget> dias, {bool ultima = false, bool arriba = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(border: ultima ? null : Border(bottom: BorderSide(color: Paleta.bordeSuave))),
      child: Row(
        crossAxisAlignment: arriba ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          primera,
          for (final w in dias) Padding(padding: const EdgeInsets.only(left: 6), child: w),
        ],
      ),
    );
    OutlineInputBorder borde(Color c, [double ancho = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: c, width: ancho));

    final tabla = Container(
      decoration: decoTarjeta(),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Paleta.superficieSuave,
              child: fila(
                SizedBox(width: _anchoConcepto, child: textoEncabezado('Concepto')),
                [for (final f in fechas) celdaEncabezado(f)],
              ),
            ),
            for (final (c, rotulo) in conceptosProyeccion)
              fila(concepto('$rotulo (kg)', _colorConcepto(c)), [
                for (final f in fechas)
                  SizedBox(
                    width: _anchoDia,
                    child: TextField(
                      controller: celdas['$f|$c'],
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [EntradaDecimal()],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Paleta.tinta,
                        fontFeatures: cifrasTabulares,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '0',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                        filled: true,
                        fillColor: Paleta.superficie,
                        border: borde(Paleta.borde),
                        enabledBorder: borde(Paleta.borde),
                        focusedBorder: borde(_colorConcepto(c), 1.4),
                      ),
                    ),
                  ),
              ]),
            fila(
              concepto('Vuelos del día', Paleta.terracota),
              [for (final f in fechas) SizedBox(width: _anchoDia, child: _vuelosDelDia(f))],
              ultima: true,
              arriba: true,
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Proyección operativa',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Paleta.verdeTitulo),
                ),
                Text(
                  'Kilos previstos por concepto para los próximos 11 días, cruzados con los vuelos cargados.',
                  style: TextStyle(fontSize: 12.5, color: Paleta.tintaSuave),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final elegido = await showDatePicker(
                      context: context,
                      initialDate: fechaDe(fechas.first) ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (elegido != null) alCambiarDesde(elegido);
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text('Desde ${formatearFecha(fechas.first)}'),
                ),
                FilledButton.icon(
                  onPressed: guardando ? null : alGuardar,
                  icon: guardando
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(guardando ? 'Guardando…' : 'Guardar y continuar'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        tabla,
      ],
    );
  }

  Widget _vuelosDelDia(String f) {
    final vuelos = datos.vuelosDelDia(f);
    if (vuelos.isEmpty) {
      return Center(child: Text('—', style: TextStyle(color: Paleta.tintaTenue)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final v in vuelos)
          Container(
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: Paleta.suave(Paleta.terracota, 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Paleta.terracota.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${txt(v['destino']).isEmpty ? '-' : txt(v['destino'])} · ${txt(v['vuelo']).isEmpty ? '-' : txt(v['vuelo'])}',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Paleta.tinta),
                ),
                Text(
                  '${txt(v['linea_aerea']).isEmpty ? '' : '${txt(v['linea_aerea'])} · '}${numDe(v['pcs']).toInt()} pallets',
                  style: TextStyle(fontSize: 10.5, color: Paleta.tintaSuave),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ───────────────────────────── Solapa 2: Programa ─────────────────────────────

/// Resumen de la proyección guardada (11 tarjetas por día) arriba de la grilla de programas.
class _BannerProyeccion extends StatelessWidget {
  const _BannerProyeccion({required this.datos, required this.fechas});

  final DatosPrograma datos;
  final List<String> fechas;

  @override
  Widget build(BuildContext context) {
    var total = 0.0;
    final tarjetas = <Widget>[];
    for (final (i, f) in fechas.indexed) {
      final p = datos.proyecciones[f];
      final valores = [for (final (c, r) in conceptosProyeccion) (c, r, numDe(p?['${c}_kg']))];
      total += valores.fold(0.0, (s, v) => s + v.$3);
      tarjetas.add(Container(
        width: 168,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Paleta.superficieSuave,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Paleta.bordeSuave),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Día ${i + 1} · ${diaMes(f)}',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Paleta.verdeTitulo),
            ),
            const SizedBox(height: 4),
            for (final (c, r, kg) in valores)
              Row(
                children: [
                  _punto(_colorConcepto(c)),
                  Expanded(child: Text(r, style: TextStyle(fontSize: 11.5, color: Paleta.tintaSuave))),
                  Text(
                    '${fmtNum(kg)} kg',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Paleta.tinta,
                      fontFeatures: cifrasTabulares,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ));
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: decoTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Proyección en curso · desde ${formatearFecha(fechas.first)}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Paleta.tinta),
                ),
              ),
              Text(
                '${fmtNum(total)} kg proyectados',
                style: TextStyle(fontWeight: FontWeight.w800, color: Paleta.verde, fontFeatures: cifrasTabulares),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: tarjetas)),
        ],
      ),
    );
  }
}

const _columnas = [
  (2, 'Fecha', false),
  (3, 'Programa', false),
  (2, 'Camión', false),
  (3, 'Cliente', false),
  (3, 'Consignatario', false),
  (2, 'Marca', false),
  (2, 'Pallets', true),
  (2, 'Destino', false),
  (2, 'Vuelo', false),
  (3, 'Salida empaque', false),
];
const _anchoAcciones = 176.0;

class _EncabezadoProgramas extends StatelessWidget {
  const _EncabezadoProgramas();

  @override
  Widget build(BuildContext context) => Container(
    height: 38,
    decoration: decoFilaTabla(primera: true),
    child: FilaTabla(
      celdas: [for (final (f, t, der) in _columnas) (f, textoEncabezado(t), der)],
      anchoAcciones: _anchoAcciones,
    ),
  );
}

typedef _AccionPrograma = void Function(ProgramaAgrupado p);

Widget _botonesPrograma(ProgramaAgrupado p, _AccionPrograma alEditar, _AccionPrograma alCopiar) => Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    TextButton.icon(
      onPressed: () => alEditar(p),
      icon: const Icon(Icons.edit_rounded, size: 16),
      label: const Text('Editar'),
    ),
    TextButton.icon(
      onPressed: () => alCopiar(p),
      icon: const Icon(Icons.copy_rounded, size: 16),
      label: const Text('Copiar'),
    ),
  ],
);

class _FilaPrograma extends StatelessWidget {
  const _FilaPrograma({
    required this.p,
    required this.ultima,
    required this.alAbrir,
    required this.alEditar,
    required this.alCopiar,
  });

  final ProgramaAgrupado p;
  final bool ultima;
  final _AccionPrograma alAbrir;
  final _AccionPrograma alEditar;
  final _AccionPrograma alCopiar;

  @override
  Widget build(BuildContext context) {
    TextStyle estilo({bool negrita = false, bool suave = false}) => TextStyle(
      fontSize: 12.8,
      fontWeight: negrita ? FontWeight.w700 : FontWeight.w400,
      color: suave ? Paleta.tintaSuave : Paleta.tinta,
    );
    Widget t(String s, {bool negrita = false, bool suave = false}) => Text(
      s.isEmpty ? '-' : s,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: estilo(negrita: negrita, suave: suave),
    );
    return GestureDetector(
      onTap: () => alAbrir(p),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ContenedorFila(
          decoration: decoFilaTabla(ultima: ultima),
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(vertical: 6),
          clave: 'prg-${p.nro}',
          child: FilaTabla(
            anchoAcciones: _anchoAcciones,
            acciones: _botonesPrograma(p, alEditar, alCopiar),
            celdas: [
              (2, t(formatearFecha(p.fecha), negrita: true), false),
              (
                3,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Pastilla(texto: p.nro, color: Paleta.azul)),
                    if (p.pendiente) ...[const SizedBox(width: 4), const IndicadorSync(sincronizado: 0)],
                  ],
                ),
                false,
              ),
              (2, Pastilla(texto: p.camion, color: Paleta.verde, icono: Icons.local_shipping_rounded), false),
              (3, t(p.cliente, negrita: true), false),
              (3, t(p.consignatario, suave: true), false),
              (2, t(p.marca), false),
              (
                2,
                Text('${fmtNum(p.pallets)} pl', style: estilo(negrita: true).copyWith(fontFeatures: cifrasTabulares)),
                true,
              ),
              (2, t(p.destino), false),
              (2, t(p.vuelo, negrita: true), false),
              (3, t(salidaLegible(p.salidaEmpaque), suave: true), false),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaPrograma extends StatelessWidget {
  const _TarjetaPrograma({required this.p, required this.alAbrir, required this.alEditar, required this.alCopiar});

  final ProgramaAgrupado p;
  final _AccionPrograma alAbrir;
  final _AccionPrograma alEditar;
  final _AccionPrograma alCopiar;

  @override
  Widget build(BuildContext context) {
    final suave = TextStyle(fontSize: 12.5, color: Paleta.tintaSuave);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => alAbrir(p),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
            decoration: decoTarjeta(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Pastilla(texto: p.nro, color: Paleta.azul)),
                    if (p.pendiente) ...[const SizedBox(width: 6), const IndicadorSync(sincronizado: 0)],
                    const Spacer(),
                    Text(
                      '${fmtNum(p.pallets)} pl',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Paleta.verdeTitulo),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  p.cliente.isEmpty ? '-' : p.cliente,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Paleta.tinta),
                ),
                Text('${p.consignatario} · ${p.marca.isEmpty ? '-' : p.marca}', style: suave),
                Text(
                  '${formatearFecha(p.fecha)} · ${p.camion} · ${p.destino.isEmpty ? '-' : p.destino}'
                  ' · vuelo ${p.vuelo.isEmpty ? '-' : p.vuelo}',
                  style: suave,
                ),
                Text('Salida empaque ${salidaLegible(p.salidaEmpaque)}', style: suave),
                _botonesPrograma(p, alEditar, alCopiar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
