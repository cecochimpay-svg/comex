import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/db/filas.dart';
import '../../core/formato.dart';
import '../../core/red.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/formulario.dart';
import '../../widgets/listados.dart';
import 'programa_datos.dart';
import 'programa_pdf.dart';
import 'programa_repo.dart';

// ═══════════════════════════ Editor del programa ═══════════════════════════

enum ModoPrograma { nuevo, editar, copiar }

/// Con qué se abre el editor (nuevo, edición o copia de un programa existente).
class AperturaPrograma {
  const AperturaPrograma({
    required this.modo,
    required this.fecha,
    required this.salida,
    required this.nro,
    this.bloques = const [],
    this.programaOriginal,
    this.originales = const [],
    this.usuarioOriginal,
    this.avisoInicial,
  });

  final ModoPrograma modo;
  final String fecha;

  /// Salida de empaque "AAAA-MM-DDTHH:MM".
  final String salida;
  final String nro;
  final List<Bloque> bloques;
  final String? programaOriginal;

  /// Renglones del programa antes de editar (para borrar los que se quiten).
  final List<Fila> originales;

  /// En edición el programa conserva el usuario que lo creó.
  final String? usuarioOriginal;
  final String? avisoInicial;
}

/// Resultado del guardado: mensaje para el aviso y si quedó todo en la nube.
typedef ResultadoPrograma = ({String mensaje, bool enNube});

Future<ResultadoPrograma?> dialogoPrograma(
  BuildContext context,
  DatosPrograma datos,
  AperturaPrograma apertura, {
  required String usuario,
}) => showDialog<ResultadoPrograma>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _EditorPrograma(datos: datos, apertura: apertura, usuario: usuario),
);

class _EditorPrograma extends StatefulWidget {
  const _EditorPrograma({required this.datos, required this.apertura, required this.usuario});

  final DatosPrograma datos;
  final AperturaPrograma apertura;
  final String usuario;

  @override
  State<_EditorPrograma> createState() => _EditorProgramaState();
}

// ── Medidas de la planilla (iguales a las columnas del Excel "PROGRAMA DE TRABAJO") ──
const _wAcento = 24.0; // N° de bloque
const _wForwarder = 138.0;
const _wCliente = 168.0;
const _wMarca = 126.0;
const _wCalibre = 56.0;
const _wCant = 52.0;
const _wTam = 58.0;
const _wPallet = 204.0;
const _wVuelo = 164.0; // vuelo + destino + cupo
const _wSalida = 92.0; // salida de empaque
const _wAcciones = 36.0;
const _anchoPlanilla =
    _wAcento + _wForwarder + _wCliente + _wMarca + _wCalibre + _wCant + _wTam + _wPallet + _wVuelo + _wSalida + _wAcciones;
const _anchoPanelStock = 372.0;

/// Un bloque de la planilla mientras se edita: cliente + marca + vuelo, con un renglón por calibre.
class _BloqueEdit {
  _BloqueEdit({
    required this.camion,
    this.forwarder = '',
    this.cliente,
    this.consignatario = '',
    this.marca,
    String destino = '',
    this.vuelo = '',
    this.awb = '',
    this.horaVuelo = '',
  }) : destino = TextEditingController(text: destino);

  /// Bloque guardado (uno por calibre) -> bloque editable. Los calibres fuera de la grilla, o repetidos,
  /// se conservan tal cual en [fuera] para no perderlos al guardar.
  factory _BloqueEdit.desde(Bloque b) {
    final e = _BloqueEdit(
      camion: b.camion,
      cliente: b.cliente.isEmpty ? null : b.cliente,
      consignatario: b.consignatario == '-' ? '' : b.consignatario,
      marca: b.marca.isEmpty ? null : b.marca,
      destino: b.destino,
      vuelo: b.vuelo == '-' ? '' : b.vuelo,
      awb: b.awb,
      horaVuelo: b.horaSalidaVuelo,
    );
    for (final c in b.calibres) {
      if (!calibresPrograma.contains(c.calibre) || e.cantDe(c.calibre) > 0 || e.ids.containsKey(c.calibre)) {
        e.fuera.add(c);
        continue;
      }
      e.cant[c.calibre]!.text = c.cantidad > 0 ? '${c.cantidad}' : '';
      e.tam[c.calibre]!.text = c.tamano.isEmpty ? 'STD' : c.tamano;
      e.pallets[c.calibre]!.addAll(separarPallets(c.nroPallet));
      if (c.id != null) e.ids[c.calibre] = c.id!;
    }
    return e;
  }

  final int clave = nuevoIdTemp();
  String camion;

  /// Forwarder (en mayúsculas) que filtra los vuelos del bloque. No se guarda: sale del vuelo elegido.
  String forwarder;
  String? cliente;
  String consignatario;
  String? marca;
  final TextEditingController destino;
  String vuelo;

  /// Plaza elegida del vuelo (AWB): cada una tiene su propia capacidad.
  String awb;
  String horaVuelo;

  final cant = {for (final c in calibresPrograma) c: TextEditingController()};
  final tam = {for (final c in calibresPrograma) c: TextEditingController(text: 'STD')};
  final pallets = {for (final c in calibresPrograma) c: <String>[]};
  final palletIn = {for (final c in calibresPrograma) c: TextEditingController()};

  /// id de Supabase de cada calibre ya guardado (en edición se actualiza, no se duplica).
  final ids = <String, int>{};
  final fuera = <CalibreBloque>[];

  int cantDe(String c) => int.tryParse(cant[c]!.text.trim()) ?? 0;
  int get total => calibresPrograma.fold(0, (s, c) => s + cantDe(c)) + fuera.fold(0, (s, c) => s + c.cantidad);
  bool get enBlanco => total == 0 && cliente == null && marca == null;

  Bloque aBloque() => Bloque(
    idTemp: clave,
    camion: camion.isEmpty ? 'S/D' : camion,
    cliente: cliente ?? '',
    consignatario: consignatario.isEmpty ? '-' : consignatario,
    marca: marca ?? '',
    destino: destino.text.trim().toUpperCase(),
    vuelo: vuelo.isEmpty ? '-' : vuelo,
    awb: awb,
    horaSalidaVuelo: horaVuelo,
    calibres: [
      for (final c in calibresPrograma)
        if (cantDe(c) > 0)
          CalibreBloque(
            calibre: c,
            cantidad: cantDe(c),
            tamano: tam[c]!.text.trim().isEmpty ? 'STD' : tam[c]!.text.trim().toUpperCase(),
            nroPallet: pallets[c]!.isEmpty ? null : pallets[c]!.join(', '),
            id: ids[c],
          ),
      ...fuera,
    ],
  );

  void dispose() {
    destino.dispose();
    for (final m in [cant, tam, palletIn]) {
      for (final c in m.values) {
        c.dispose();
      }
    }
  }
}

class _EditorProgramaState extends State<_EditorPrograma> {
  DatosPrograma get d => widget.datos;
  AperturaPrograma get a => widget.apertura;
  bool get _edicion => a.modo == ModoPrograma.editar;

  late final TextEditingController _nro = TextEditingController(text: a.nro);
  late String _fecha = a.fecha;
  late String _salida = a.salida;
  /// Vuelos del día con sus plazas (AWB) juntas: una opción por vuelo, con la capacidad sumada.
  late List<Fila> _vuelosDia = d.plazasDelDia(_fecha);

  late final List<_BloqueEdit> _bloques = _crearBloques();

  /// El camión se asigna después, al editar el programa: en alta y copia no se muestra (queda S/D).
  bool get _conCamion => _edicion;

  /// Forwarders de los vuelos de la temporada (logistitcas_temporada.forwarder, lo completa el trigger).
  late final List<String> _forwarders = {
    for (final v in d.vuelos)
      if (txt(v['forwarder']).isNotEmpty) txt(v['forwarder']).toUpperCase(),
  }.toList()
    ..sort();

  List<_BloqueEdit> _crearBloques() {
    if (a.bloques.isEmpty) return [_BloqueEdit(camion: 'S/D')];
    return [
      for (final b in a.bloques)
        _BloqueEdit.desde(b)
          ..forwarder = _forwarderDeVuelo(b.vuelo)
          ..camion = _conCamion ? b.camion : 'S/D',
    ];
  }

  String _forwarderDe(Fila v) => txt(v['forwarder']).toUpperCase();

  /// Forwarder del vuelo (se busca primero en los del día y si no en toda la temporada).
  String _forwarderDeVuelo(String vuelo) {
    if (vuelo.isEmpty || vuelo == '-') return '';
    for (final lista in [d.vuelosDelDia(a.fecha), d.vuelos]) {
      for (final v in lista) {
        if (txt(v['vuelo']) == vuelo && _forwarderDe(v).isNotEmpty) return _forwarderDe(v);
      }
    }
    return '';
  }

  /// Vuelos del día que puede elegir el bloque (los de su forwarder, o todos si no eligió).
  List<Fila> _vuelosDe(_BloqueEdit b) =>
      b.forwarder.isEmpty ? _vuelosDia : [for (final v in _vuelosDia) if (_forwarderDe(v) == b.forwarder) v];

  void _elegirForwarder(_BloqueEdit b, String? f) => setState(() {
    b.forwarder = f ?? '';
    if (b.vuelo.isNotEmpty && !_vuelosDe(b).any((v) => _vueloDe(v) == b.vuelo)) {
      b.vuelo = ''; // el vuelo elegido no es de ese forwarder
      b.awb = '';
      b.horaVuelo = '';
    }
  });

  /// Bloque al que se vuelcan los pallets del stock (el último que se tocó).
  int _activo = 0;

  (String, bool)? _mensaje; // (texto, es error)
  bool _guardando = false;
  final _scrollPlanilla = ScrollController();

  // ── Stock ──
  List<PalletStock> _stock = const [];
  bool _cargandoStock = true;
  bool _stockOffline = false;
  String? _errorStock;
  bool _soloMarcaBloque = true;
  bool _stockAbierto = false; // solapa de archivero: cerrada no ocupa lugar
  String? _filtroCalibre; // null = todos · '' = fuera de la grilla
  String? _filtroColor; // null = todos
  bool _resumenAbierto = true;
  bool _ocultarProgramados = true;
  final _buscarStock = TextEditingController();

  /// Pallets que ya están en otros programas de la temporada (N° pallet -> N° programa).
  late final Map<String, String> _programados =
      d.palletsProgramados(excluirPrograma: _edicion ? a.programaOriginal : null);

  _BloqueEdit get _bloqueActivo => _bloques[_activo.clamp(0, _bloques.length - 1)];

  @override
  void initState() {
    super.initState();
    if (a.avisoInicial != null) _mensaje = (a.avisoInicial!, false);
    _cargarStock(inicial: true);
  }

  @override
  void dispose() {
    _nro.dispose();
    _buscarStock.dispose();
    _scrollPlanilla.dispose();
    for (final b in _bloques) {
      b.dispose();
    }
    super.dispose();
  }

  void _avisar(String texto, {bool error = false}) => setState(() => _mensaje = (texto, error));

  // ─────────────────────────── Stock ───────────────────────────

  Future<void> _cargarStock({bool inicial = false}) async {
    if (!inicial) {
      setState(() {
        _cargandoStock = true;
        _errorStock = null;
      });
    }
    try {
      final lectura = await RepoPrograma.stock();
      if (!mounted) return;
      setState(() {
        _stock = palletsDesdeStock(lectura.filas);
        _stockOffline = lectura.offline;
        _cargandoStock = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stock = const [];
        _errorStock = mensajeDe(e);
        _cargandoStock = false;
      });
    }
  }

  OpcionMarca? _opcionMarca(String? nombre) => nombre == null ? null : d.marcas.where((m) => m.nombre == nombre).firstOrNull;

  bool _esDeMarca(PalletStock p, String marca) => p.esDeMarca(marca, _opcionMarca(marca)?.abreviatura ?? '');

  /// Marca del catálogo que corresponde a la del stock (por detalle o abreviatura).
  String? _marcaDeStock(String marcaStock) {
    final m = marcaStock.trim().toUpperCase();
    if (m.isEmpty || m.contains(' / ')) return null;
    for (final o in d.marcas) {
      if (o.nombre.trim().toUpperCase() == m || o.abreviatura.trim().toUpperCase() == m) return o.nombre;
    }
    return marcaStock.trim();
  }

  int _stockDeMarca(String marca) => _stock.where((p) => _esDeMarca(p, marca)).length;

  /// Dónde está cada pallet de la planilla: N° pallet -> (índice de bloque, calibre).
  Map<String, (int, String)> _palletsEnPlanilla() {
    final r = <String, (int, String)>{};
    for (final (i, b) in _bloques.indexed) {
      for (final c in calibresPrograma) {
        for (final p in b.pallets[c]!) {
          r.putIfAbsent(p, () => (i, c));
        }
      }
      for (final f in b.fuera) {
        for (final p in separarPallets(f.nroPallet)) {
          r.putIfAbsent(p, () => (i, f.calibre));
        }
      }
    }
    return r;
  }

  void _sacarPallet(_BloqueEdit b, String calibre, String pallet) {
    final lista = b.pallets[calibre]!..remove(pallet);
    b.cant[calibre]!.text = lista.isEmpty ? '' : '${lista.length}';
  }

  /// Toque en un pallet del stock: si ya está en el bloque activo se quita; si no, va al renglón de su calibre.
  void _tocarPallet(PalletStock p) {
    final ubicacion = _palletsEnPlanilla()[p.pallet];
    if (ubicacion != null && ubicacion.$1 == _activo && calibresPrograma.contains(ubicacion.$2)) {
      setState(() => _sacarPallet(_bloqueActivo, ubicacion.$2, p.pallet));
      return;
    }
    final destino = p.calibreGrilla;
    if (destino == null) {
      return _avisar(
        'El calibre "${p.calibreOrigen}" del pallet ${p.pallet} no está en la grilla: elegí el renglón con el menú ⋮.',
        error: true,
      );
    }
    _volcarPallet(p, destino);
  }

  /// Vuelca el pallet al renglón [calibre] del bloque activo (la cantidad sigue a los pallets cargados).
  Future<void> _volcarPallet(PalletStock p, String calibre) async {
    final b = _bloqueActivo;
    final ubicacion = _palletsEnPlanilla()[p.pallet];
    if (ubicacion != null && ubicacion.$1 != _activo) {
      return _avisar('El pallet ${p.pallet} ya está en el bloque #${ubicacion.$1 + 1} (calibre ${ubicacion.$2}).',
          error: true);
    }
    if (ubicacion != null && !calibresPrograma.contains(ubicacion.$2)) {
      return _avisar('El pallet ${p.pallet} ya está en este bloque (calibre ${ubicacion.$2}).', error: true);
    }
    if (ubicacion?.$2 == calibre) return;

    final otro = _programados[p.pallet];
    if (otro != null && ubicacion == null) {
      final ok = await confirmar(
        context,
        titulo: 'Pallet ya programado',
        mensaje: 'El pallet ${p.pallet} ya figura en el programa N° $otro. ¿Volcarlo igual?',
        textoOk: 'Volcar igual',
      );
      if (!ok || !mounted) return;
    }
    String? marcaNueva;
    if (b.marca == null) {
      marcaNueva = _marcaDeStock(p.marca); // bloque sin marca: toma la del pallet
    } else if (p.marca.isNotEmpty && !_esDeMarca(p, b.marca!)) {
      final ok = await confirmar(
        context,
        titulo: 'Marca distinta',
        mensaje: 'El pallet ${p.pallet} es de ${p.marca} y el bloque #${_activo + 1} es de ${b.marca}. ¿Volcarlo igual?',
        textoOk: 'Volcar igual',
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      if (marcaNueva != null) b.marca = marcaNueva;
      if (ubicacion != null) _sacarPallet(b, ubicacion.$2, p.pallet); // se mueve de renglón
      b.pallets[calibre]!.add(p.pallet);
      b.cant[calibre]!.text = '${b.pallets[calibre]!.length}';
    });
  }

  // ─────────────────────────── Planilla ───────────────────────────

  String _vueloDe(Fila v) => txt(v['vuelo']).isEmpty ? '-' : txt(v['vuelo']);

  String _horaDe(Fila v) {
    final h = '${txt(v['fecha_etd1'])} ${txt(v['hora_etd1'])}'.trim();
    return h.isEmpty ? 'S/D' : h;
  }

  bool _vueloEnFecha(String vuelo) => _vuelosDia.any((v) => _vueloDe(v) == vuelo);

  String _awbDe(Fila v) => txt(v['awb']);

  /// (capacidad, usados) de UNA plaza (vuelo + AWB). Sin AWB (programas viejos) se mide el vuelo entero.
  (int, int) _cupoPlaza(String vuelo, String awb) {
    if (awb.isEmpty) return _cupoVuelo(vuelo);
    final plaza = _vuelosDia.where((v) => _vueloDe(v) == vuelo && _awbDe(v) == awb).firstOrNull;
    final capacidad = plaza == null ? 0 : numDe(plaza['pcs']).toInt();
    final guardados = d.palletsGuardadosEnPlaza(vuelo, _fecha, awb,
        excluirPrograma: _edicion ? a.programaOriginal : null);
    final enPlanilla = _bloques.where((b) => b.vuelo == vuelo && b.awb == awb).fold(0, (s, b) => s + b.total);
    return (capacidad, guardados + enPlanilla);
  }

  /// (capacidad, usados) del vuelo entero (todas sus plazas): lo guardado en otros programas + esta planilla.
  (int, int) _cupoVuelo(String vuelo) {
    // Todas las plazas del vuelo ese día (si dos forwarders comparten el vuelo, se suman las de ambos).
    final capacidad = _vuelosDia.where((v) => _vueloDe(v) == vuelo).fold(0, (s, v) => s + numDe(v['pcs']).toInt());
    final guardados =
        d.palletsGuardadosEnVuelo(vuelo, _fecha, excluirPrograma: _edicion ? a.programaOriginal : null);
    final enPlanilla = _bloques.where((b) => b.vuelo == vuelo).fold(0, (s, b) => s + b.total);
    return (capacidad, guardados + enPlanilla);
  }

  void _elegirCliente(_BloqueEdit b, String? cliente) => setState(() {
    b.cliente = cliente;
    b.consignatario = ''; // se deduce al guardar con cliente + destino
    final lista = d.clientes[cliente] ?? const <OpcionConsignatario>[];
    // Sin destino todavía: se propone el habitual del cliente (el vuelo lo puede completar después).
    if (b.destino.text.trim().isEmpty && lista.isNotEmpty && lista.first.destino.isNotEmpty) {
      b.destino.text = lista.first.destino;
    }
  });

  /// Consignatario que corresponde a cliente + destino (clientes_consignatarios). Si el cliente tiene uno
  /// solo, ése. Si no se encuentra, se conserva el que tenía guardado (o queda "-").
  String _consignatarioPara(_BloqueEdit b) {
    final lista = d.clientes[b.cliente] ?? const <OpcionConsignatario>[];
    final destino = b.destino.text.trim().toUpperCase();
    for (final o in lista) {
      if (o.destino.trim().toUpperCase() == destino && destino.isNotEmpty) return o.consignatario;
    }
    final distintos = {for (final o in lista) o.consignatario};
    if (distintos.length == 1) return distintos.first;
    return b.consignatario;
  }

  void _elegirVuelo(_BloqueEdit b, Fila? v) => setState(() {
    if (v == null) {
      b.vuelo = '';
      b.awb = '';
      b.horaVuelo = '';
      return;
    }
    b.vuelo = _vueloDe(v);
    b.awb = _awbDe(v);
    if (b.forwarder.isEmpty) b.forwarder = _forwarderDe(v);
    b.horaVuelo = _horaDe(v);
    if (b.destino.text.trim().isEmpty) b.destino.text = txt(v['destino']);
  });

  /// Pasa a chips lo tipeado en "N° pallet" (uno, varios con coma o rango 200-205).
  void _confirmarTipeo(_BloqueEdit b, String calibre) {
    final texto = b.palletIn[calibre]!.text.trim();
    if (texto.isEmpty) return;
    final lista = b.pallets[calibre]!;
    for (final p in parsearRangoPallets(texto)) {
      if (!lista.contains(p)) lista.add(p);
    }
    b.palletIn[calibre]!.clear();
    b.cant[calibre]!.text = '${lista.length}';
  }

  void _agregarBloque({_BloqueEdit? como}) {
    if (_bloques.length >= maxBloquesPrograma) {
      return _avisar('Límite de $maxBloquesPrograma bloques alcanzado para este programa.', error: true);
    }
    setState(() {
      _bloques.add(_BloqueEdit(
        camion: _conCamion ? (como?.camion ?? _bloques.lastOrNull?.camion ?? nombreCamion(1)) : 'S/D',
        forwarder: como?.forwarder ?? _bloques.lastOrNull?.forwarder ?? '',
        cliente: como?.cliente,
        consignatario: '',
        marca: como?.marca,
        destino: como?.destino.text ?? '',
        vuelo: como?.vuelo ?? _bloques.lastOrNull?.vuelo ?? '',
        awb: como?.awb ?? _bloques.lastOrNull?.awb ?? '',
        horaVuelo: como?.horaVuelo ?? _bloques.lastOrNull?.horaVuelo ?? '',
      ));
      _activo = _bloques.length - 1;
    });
  }

  Future<void> _quitarBloque(_BloqueEdit b) async {
    if (b.total > 0) {
      final ok = await confirmar(
        context,
        titulo: 'Quitar bloque',
        mensaje: 'El bloque #${_bloques.indexOf(b) + 1} tiene ${b.total} pallets cargados. ¿Quitarlo?',
        textoOk: 'Quitar',
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _bloques.remove(b);
      if (_bloques.isEmpty) _bloques.add(_BloqueEdit(camion: 'S/D'));
      _activo = _activo.clamp(0, _bloques.length - 1);
    });
    // Los campos del bloque se desmontan en este cuadro: se liberan después.
    WidgetsBinding.instance.addPostFrameCallback((_) => b.dispose());
  }

  void _aplicarVueloATodos() {
    final origen = _bloqueActivo;
    if (origen.vuelo.isEmpty) {
      return _avisar('Elegí primero el vuelo del bloque #${_activo + 1}.', error: true);
    }
    setState(() {
      for (final b in _bloques) {
        b.vuelo = origen.vuelo;
        b.awb = origen.awb;
        b.horaVuelo = origen.horaVuelo;
        b.forwarder = origen.forwarder;
      }
      _mensaje = ('Vuelo ${origen.vuelo} aplicado a ${_bloques.length} bloque(s).', false);
    });
  }

  // ── Fechas ──

  Future<void> _elegirFecha() async {
    final elegido = await showDatePicker(
      context: context,
      initialDate: fechaDe(_fecha) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (elegido == null) return;
    setState(() {
      _fecha = isoDe(elegido);
      _vuelosDia = d.plazasDelDia(_fecha); // los bloques con vuelo de otra fecha quedan marcados
    });
  }

  Future<void> _elegirSalida() async {
    final actual = DateTime.tryParse(_salida) ?? DateTime.now();
    final dia = await showDatePicker(
      context: context,
      initialDate: actual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (dia == null || !mounted) return;
    final hora = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(actual));
    if (hora == null) return;
    setState(() => _salida =
        '${isoDe(dia)}T${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}');
  }

  // ─────────────────────────── Guardar ───────────────────────────

  Future<void> _guardar() async {
    setState(() {
      for (final b in _bloques) {
        for (final c in calibresPrograma) {
          _confirmarTipeo(b, c);
        }
      }
    });
    final usados = [for (final b in _bloques) if (!b.enBlanco) b];
    if (usados.every((b) => b.total == 0)) {
      return _avisar('Cargá al menos un bloque con pallets.', error: true);
    }
    for (final (i, b) in _bloques.indexed) {
      if (b.enBlanco) continue;
      final n = '#${i + 1}';
      if (b.cliente == null || b.marca == null) return _avisar('Bloque $n: elegí cliente y marca.', error: true);
      if (b.total == 0) return _avisar('Bloque $n: no tiene pallets cargados (o quitalo).', error: true);
      if (b.vuelo.isEmpty) return _avisar('Bloque $n: elegí el vuelo.', error: true);
    }

    final nro = _nro.text.trim();
    if (nro.isEmpty || _fecha.isEmpty) {
      return _avisar('Completá el N° de programa y la fecha de empaque.', error: true);
    }
    // Programa nuevo o copia: N° numérico correlativo. En edición se respeta el que tenía (los viejos son "PRG-…").
    if (!_edicion && !nroProgramaValido(nro)) {
      return _avisar('El N° de programa tiene que ser un número (el siguiente es ${d.siguienteNro}).', error: true);
    }
    if (d.nroEnUso(nro, salvo: _edicion ? a.programaOriginal : null)) {
      if (!_edicion) _nro.text = d.siguienteNro;
      return _avisar(
        'Ya existe un programa con el N° $nro.${_edicion ? '' : ' Te dejé el ${d.siguienteNro}: guardá de nuevo.'}',
        error: true,
      );
    }
    if (!_edicion) {
      // Otro usuario pudo haber guardado un programa mientras éste estaba abierto: se revisa en la nube.
      setState(() => _guardando = true);
      final enNube = await RepoPrograma.nrosEnNube();
      if (!mounted) return;
      setState(() => _guardando = false);
      if (enNube != null && enNube.contains(nro)) {
        final libre = siguienteNroPrograma([...enNube, ...d.renglones.map((r) => r['programa_nro'])]);
        _nro.text = '$libre';
        return _avisar('Otro usuario acaba de guardar el programa N° $nro. Te dejé el $libre: guardá de nuevo.',
            error: true);
      }
    }
    final raros = usados.where((b) => !_vueloEnFecha(b.vuelo)).length;
    if (raros > 0 && d.vuelos.isNotEmpty) {
      final ok = await confirmar(
        context,
        titulo: 'Vuelos de otra fecha',
        mensaje: '$raros bloque(s) tienen un vuelo que no sale el ${formatearFecha(_fecha)}. ¿Guardar igual?',
        textoOk: 'Guardar igual',
      );
      if (!ok || !mounted) return;
    }
    final excedidos = <String>[];
    for (final (vuelo, awb) in {for (final b in usados) (b.vuelo, b.awb)}) {
      final (capacidad, ocupados) = _cupoPlaza(vuelo, awb);
      if (capacidad > 0 && ocupados > capacidad) {
        excedidos.add('$vuelo${awb.isEmpty ? '' : ' AWB $awb'} ($ocupados de $capacidad)');
      }
    }
    if (excedidos.isNotEmpty) {
      final ok = await confirmar(
        context,
        titulo: 'Vuelo completo',
        mensaje: 'Se supera la capacidad (PCS) de: ${excedidos.join(', ')}. ¿Guardar igual?',
        textoOk: 'Guardar igual',
      );
      if (!ok || !mounted) return;
    }

    final renglones = renglonesAGuardar(
      bloques: [for (final b in usados) (b..consignatario = _consignatarioPara(b)).aBloque()],
      nro: nro,
      fecha: _fecha,
      salidaEmpaque: _salida.isEmpty ? null : _salida,
      usuario: _edicion && (a.usuarioOriginal ?? '').isNotEmpty ? a.usuarioOriginal! : widget.usuario,
      edicion: _edicion,
    );

    setState(() {
      _guardando = true;
      _mensaje = null;
    });
    try {
      final omitidas = <String>[];
      final enNube = await RepoPrograma.guardarPrograma(
        renglones: renglones,
        originales: _edicion ? a.originales : const [],
        omitidas: omitidas,
      );
      if (!mounted) return;
      final accion = _edicion ? 'actualizado' : 'guardado';
      final sinColumna = [
        if (omitidas.contains('consignatario')) ' La nube no tiene la columna consignatario (migración 001): se guardó sin ella.',
        if (omitidas.contains('awb')) ' La nube no tiene la columna awb en comex_programa_trabajo: se guardó sin la AWB.',
      ].join();
      Navigator.pop<ResultadoPrograma>(context, (
        mensaje: 'Programa $nro $accion (${renglones.length} renglones).'
            '${enNube ? '' : ' Sin conexión: se subirá al sincronizar.'}$sinColumna',
        enNube: enNube,
      ));
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _mensaje = ('No se pudo guardar el programa: ${mensajeDe(e)}', true);
        });
      }
    }
  }

  // ─────────────────────────── Pantalla ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final titulo = switch (a.modo) {
      ModoPrograma.nuevo => 'Nuevo programa',
      ModoPrograma.editar => 'Editar programa ${a.programaOriginal}',
      ModoPrograma.copiar => 'Copia de ${a.programaOriginal}',
    };
    final total = _bloques.fold(0, (s, b) => s + b.total);
    final enPlanilla = _palletsEnPlanilla();
    return MarcoDialogo(
      titulo: titulo,
      subtitulo: '${_bloques.length} de $maxBloquesPrograma bloques · ${fmtNum(total)} pallets'
          '${_edicion ? ' · Edición' : a.modo == ModoPrograma.copiar ? ' · Copia' : ''}',
      icono: a.modo == ModoPrograma.editar ? Icons.edit_note_rounded : Icons.event_note_rounded,
      tono: Paleta.verde,
      anchoMaximo: _stockAbierto ? 1680 : 1280, // compacto; al abrir el stock se ensancha
      acciones: [
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(_guardando ? 'Guardando…' : (_edicion ? 'Guardar cambios' : 'Guardar programa')),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, c) {
          final ancha = c.maxWidth >= 1150;
          final alto = (MediaQuery.sizeOf(context).height * 0.68).clamp(440.0, 940.0);
          final planilla = _planilla(total);
          final stock = _panelStock(enPlanilla, alto);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_mensaje != null) ...[_banner(_mensaje!.$1, _mensaje!.$2), const SizedBox(height: 10)],
              if (ancha)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: planilla),
                    const SizedBox(width: 8),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      child: _stockAbierto
                          ? SizedBox(width: _anchoPanelStock, child: stock)
                          : const SizedBox(width: 0, height: 0),
                    ),
                    _solapaStock(vertical: true),
                  ],
                )
              else ...[
                planilla,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: _solapaStock(vertical: false)),
                if (_stockAbierto) stock,
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _banner(String texto, bool error) {
    final color = error ? Paleta.peligro : Paleta.azul;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Paleta.suave(color, 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(error ? Icons.error_outline_rounded : Icons.info_outline_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ),
          IconButton(
            tooltip: 'Cerrar aviso',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 16, color: color),
            onPressed: () => setState(() => _mensaje = null),
          ),
        ],
      ),
    );
  }

  // ── Estilos de celda ──

  Color get _linea => Paleta.borde;
  Color get _lineaFuerte => Paleta.tinta.withValues(alpha: 0.45);

  TextStyle get _estiloCelda => TextStyle(fontSize: 12.5, color: Paleta.tinta, fontWeight: FontWeight.w600);

  TextStyle get _estiloEncabezado =>
      const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5);

  InputDecoration _decoPlana(String pista, {bool centrado = false}) => InputDecoration(
    isDense: true,
    hintText: pista,
    hintStyle: TextStyle(fontSize: 12, color: Paleta.tintaTenue, fontWeight: FontWeight.w400),
    contentPadding: EdgeInsets.symmetric(horizontal: centrado ? 2 : 6, vertical: 4),
    filled: true,
    fillColor: Colors.transparent,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: Paleta.verde, width: 1.4),
    ),
  );

  Widget _textoCelda(String s, {Color? color, bool negrita = false, double tam = 12.5}) => Text(
    s,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: tam, color: color ?? Paleta.tinta, fontWeight: negrita ? FontWeight.w800 : FontWeight.w500),
  );

  // ── Planilla completa ──

  Widget _planilla(int total) => Container(
    decoration: BoxDecoration(
      color: Paleta.superficie,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _lineaFuerte, width: 1.2),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tituloPlanilla(),
        _cabeceraDatos(),
        Scrollbar(
          controller: _scrollPlanilla,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollPlanilla,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: _anchoPlanilla,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _encabezadoColumnas(),
                  for (final (i, b) in _bloques.indexed) _filaBloque(i, b),
                ],
              ),
            ),
          ),
        ),
        _piePlanilla(total),
      ],
    ),
  );

  Widget _tituloPlanilla() => Container(
    padding: const EdgeInsets.symmetric(vertical: 3),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _lineaFuerte, width: 1.2))),
    child: Text(
      'PROGRAMA DE TRABAJO',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: 1.5,
        color: Paleta.tinta,
      ),
    ),
  );

  /// FECHA · PROGRAMA N° · SALIDA EMPAQUE (la fila de arriba del Excel).
  Widget _cabeceraDatos() {
    Widget bloque(String rotulo, Widget valor, {int flex = 1, bool ultima = false}) => Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
        decoration: BoxDecoration(
          border: Border(right: ultima ? BorderSide.none : BorderSide(color: _linea)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Paleta.tintaSuave)),
            valor,
          ],
        ),
      ),
    );
    Widget tocable(String valor, IconData icono, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Paleta.tinta)),
            ),
            Icon(icono, size: 16, color: Paleta.tintaSuave),
          ],
        ),
      ),
    );
    final semana = semanaDeFecha(_fecha);
    return Container(
      decoration: BoxDecoration(
        color: Paleta.superficieSuave,
        border: Border(bottom: BorderSide(color: _lineaFuerte, width: 1.2)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            bloque(
              'FECHA${semana == null ? '' : ' · SEMANA $semana'}',
              tocable('${diaSemana(_fecha)} ${formatearFecha(_fecha)}', Icons.calendar_today_rounded, _elegirFecha),
              flex: 3,
            ),
            bloque(
              'PROGRAMA Nº',
              TextField(
                controller: _nro,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Paleta.tinta),
                keyboardType: _edicion ? TextInputType.text : TextInputType.number,
                inputFormatters: _edicion ? null : [FilteringTextInputFormatter.digitsOnly],
                textCapitalization: TextCapitalization.characters,
                decoration: _decoPlana(d.siguienteNro).copyWith(contentPadding: const EdgeInsets.symmetric(vertical: 5)),
              ),
              flex: 2,
              ultima: true,
            ),
          ],
        ),
      ),
    );
  }

  /// Encabezado de dos niveles, con PALLET agrupando CANT · TAMAÑO · Nº PALLET.
  Widget _encabezadoColumnas() {
    const alto = 21.0;
    Widget celda(String t, double ancho, {double altura = alto * 2, bool ultima = false, bool abajo = false}) => Container(
      width: ancho,
      height: altura,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          right: ultima ? BorderSide.none : BorderSide(color: Colors.white.withValues(alpha: 0.25)),
          bottom: abajo ? BorderSide(color: Colors.white.withValues(alpha: 0.25)) : BorderSide.none,
        ),
      ),
      child: Text(t, textAlign: TextAlign.center, style: _estiloEncabezado),
    );
    return Container(
      color: Paleta.verdeOscuro,
      child: Row(
        children: [
          celda('#', _wAcento),
          celda('FORWARDER', _wForwarder),
          celda('CLIENTE', _wCliente),
          celda('VUELO\nDESTINO', _wVuelo),
          celda('MARCA', _wMarca),
          celda('CALIBRE', _wCalibre),
          Column(
            children: [
              celda('PALLET', _wCant + _wTam + _wPallet, altura: alto, abajo: true),
              Row(
                children: [
                  celda('CANT', _wCant, altura: alto),
                  celda('TAMAÑO', _wTam, altura: alto),
                  celda('Nº PALLET', _wPallet, altura: alto),
                ],
              ),
            ],
          ),
          celda('SALIDA\nEMPAQUE', _wSalida),
          celda('', _wAcciones, ultima: true),
        ],
      ),
    );
  }

  /// Un bloque = las celdas combinadas de cliente/marca/destino/vuelo + 5 renglones de calibre.
  /// Las líneas verticales se dibujan de fondo con los mismos anchos (así las celdas combinadas
  /// ocupan todo el alto sin medir nada).
  Widget _filaBloque(int i, _BloqueEdit b) {
    final activo = i == _activo;
    final anchos = [_wForwarder, _wCliente, _wVuelo, _wMarca, _wCalibre, _wCant, _wTam, _wPallet, _wSalida, _wAcciones];
    return Listener(
      onPointerDown: (_) {
        if (_activo != i) setState(() => _activo = i);
      },
      child: Container(
        decoration: BoxDecoration(
          color: activo ? Paleta.suave(Paleta.verde, 0.05) : Paleta.superficie,
          border: Border(top: BorderSide(color: _lineaFuerte, width: 1.2)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  Container(
                    width: _wAcento,
                    decoration: BoxDecoration(
                      color: activo ? Paleta.verde : Paleta.superficieSuave,
                      border: Border(right: BorderSide(color: _linea)),
                    ),
                  ),
                  for (final (j, w) in anchos.indexed)
                    Container(
                      width: w,
                      decoration: BoxDecoration(
                        color: j == 4 ? Paleta.superficieSuave : null, // columna CALIBRE sombreada
                        border: Border(
                          right: j == anchos.length - 1 ? BorderSide.none : BorderSide(color: _linea),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _wAcento,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: activo ? Colors.white : Paleta.tintaSuave),
                    ),
                  ),
                ),
                SizedBox(width: _wForwarder, child: _celdaForwarder(b)),
                SizedBox(width: _wCliente, child: _celdaCliente(b)),
                SizedBox(width: _wVuelo, child: _celdaVuelo(b)),
                SizedBox(width: _wMarca, child: _celdaMarca(b)),
                SizedBox(
                  width: _wCalibre + _wCant + _wTam + _wPallet,
                  child: Column(
                    children: [
                      for (final c in calibresPrograma) _filaCalibre(b, c, ultima: c == calibresPrograma.last && b.fuera.isEmpty),
                      if (b.fuera.isNotEmpty) _filaFuera(b),
                    ],
                  ),
                ),
                SizedBox(width: _wSalida, child: _celdaSalida()),
                SizedBox(
                  width: _wAcciones,
                  child: Column(
                    children: [
                      IconButton(
                        tooltip: 'Otro bloque igual (mismo cliente, marca y vuelo)',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.copy_all_rounded, size: 18, color: Paleta.tintaSuave),
                        onPressed: () => _agregarBloque(como: b),
                      ),
                      IconButton(
                        tooltip: 'Quitar bloque',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.delete_outline_rounded, size: 18, color: Paleta.peligro),
                        onPressed: () => _quitarBloque(b),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Forwarder (filtra los vuelos del bloque). Elegido se ve como una etiqueta azul.
  Widget _celdaForwarder(_BloqueEdit b) {
    final opciones = [..._forwarders, if (b.forwarder.isNotEmpty && !_forwarders.contains(b.forwarder)) b.forwarder];
    final elegido = b.forwarder.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          color: elegido ? Paleta.suave(Paleta.azul, 0.10) : null,
          borderRadius: BorderRadius.circular(6),
          border: elegido ? Border.all(color: Paleta.azul.withValues(alpha: 0.35)) : null,
        ),
        child: DropdownButtonFormField<String>(
          initialValue: elegido ? b.forwarder : null,
          key: ValueKey('fwd-${b.clave}-${b.forwarder}'),
          isExpanded: true,
          isDense: true,
          iconSize: 18,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Paleta.azul, letterSpacing: 0.3),
          decoration: _decoPlana('').copyWith(contentPadding: const EdgeInsets.fromLTRB(6, 7, 0, 7)),
          hint: Row(
            children: [
              Icon(Icons.flight_rounded, size: 15, color: Paleta.tintaTenue),
              const SizedBox(width: 4),
              Flexible(
                child: Text(opciones.isEmpty ? 'Sin datos' : 'Todos',
                    style: TextStyle(fontSize: 12.5, color: Paleta.tintaTenue)),
              ),
            ],
          ),
          selectedItemBuilder: (_) => [
            Text('Todos', style: TextStyle(fontSize: 12.5, color: Paleta.tintaTenue)),
            for (final f in opciones)
              Row(
                children: [
                  Icon(Icons.flight_rounded, size: 15, color: Paleta.azul),
                  const SizedBox(width: 4),
                  Flexible(child: Text(f, overflow: TextOverflow.ellipsis)),
                ],
              ),
          ],
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text('Todos los forwarders', style: TextStyle(color: Paleta.tintaSuave, fontWeight: FontWeight.w600)),
            ),
            for (final f in opciones) DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => _elegirForwarder(b, v == null || v.isEmpty ? null : v),
        ),
      ),
    );
  }

  /// Salida de empaque del programa, repetida al final de cada fila (tocarla la cambia para todo el programa).
  Widget _celdaSalida() {
    final completo = formatearFecha(_salida, conHora: true);
    final partes = completo.split(' ');
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Tooltip(
        message: 'Salida de empaque del programa (tocá para cambiarla)',
        child: InkWell(
          onTap: _elegirSalida,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partes.first, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Paleta.tinta)),
                if (partes.length > 1)
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 13, color: Paleta.verde),
                      const SizedBox(width: 3),
                      Text(partes[1],
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Paleta.verde,
                              fontFeatures: cifrasTabulares)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pallets del cliente: los de esta fila y, si el cliente está en otras filas, el total de todas.
  Widget _contadorCliente(_BloqueEdit b) {
    final filas = [for (final o in _bloques) if (o.cliente == b.cliente) o];
    final total = filas.fold(0, (s, o) => s + o.total);
    final varias = filas.length > 1;
    Widget chip(String texto, Color color, {IconData? icono, String? ayuda}) {
      final w = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Paleta.suave(color, 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[Icon(icono, size: 11, color: color), const SizedBox(width: 3)],
            Text(texto,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: color, fontFeatures: cifrasTabulares)),
          ],
        ),
      );
      return ayuda == null ? w : Tooltip(message: ayuda, child: w);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 3),
      child: Wrap(
        spacing: 4,
        runSpacing: 3,
        children: [
          chip('${fmtNum(b.total)} pl', b.total > 0 ? Paleta.verde : Paleta.tintaTenue,
              icono: Icons.inventory_2_rounded, ayuda: 'Pallets de ${b.cliente} en esta fila'),
          if (varias)
            chip('Σ ${fmtNum(total)} pl · ${filas.length} filas', Paleta.azul,
                icono: Icons.functions_rounded,
                ayuda: '${b.cliente} en todo el programa: '
                    '${filas.map((o) => '#${_bloques.indexOf(o) + 1}: ${o.total}').join(' · ')}'),
        ],
      ),
    );
  }

  Widget _celdaCliente(_BloqueEdit b) {
    final clientes = [...d.nombresClientes, if (b.cliente != null && !d.clientes.containsKey(b.cliente)) b.cliente!];
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: b.cliente,
            key: ValueKey('cli-${b.clave}-${b.cliente}'),
            isExpanded: true,
            isDense: true,
            style: _estiloCelda.copyWith(fontWeight: FontWeight.w800),
            decoration: _decoPlana(''),
            hint: Text(clientes.isEmpty ? 'Sin clientes' : 'Cliente…', style: TextStyle(fontSize: 12.5, color: Paleta.tintaTenue)),
            items: [
              for (final c in clientes) DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => _elegirCliente(b, v),
          ),
          if (b.cliente != null) _contadorCliente(b),
          if (_conCamion)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  tooltip: 'Camión del bloque',
                  initialValue: b.camion,
                  onSelected: (v) => setState(() => b.camion = v),
                  itemBuilder: (_) => [
                    for (var n = 1; n <= maxCamiones; n++)
                      PopupMenuItem(value: nombreCamion(n), child: Text(nombreCamion(n))),
                    const PopupMenuItem(value: 'S/D', child: Text('Sin camión (S/D)')),
                  ],
                  child: Pastilla(texto: b.camion, color: Paleta.verde, icono: Icons.local_shipping_rounded),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _celdaMarca(_BloqueEdit b) {
    final porNombre = <String, OpcionMarca>{};
    for (final m in d.marcas) {
      porNombre.putIfAbsent(m.nombre, () => m);
    }
    if (b.marca != null) porNombre.putIfAbsent(b.marca!, () => OpcionMarca(b.marca!, b.marca!));
    final marcas = porNombre.values.toList();
    final enStock = b.marca == null || _cargandoStock ? null : _stockDeMarca(b.marca!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 4, 3, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: b.marca,
            key: ValueKey('mar-${b.clave}-${b.marca}'),
            isExpanded: true,
            isDense: true,
            style: _estiloCelda.copyWith(fontWeight: FontWeight.w800),
            decoration: _decoPlana(''),
            hint: Text('Marca…', style: TextStyle(fontSize: 12.5, color: Paleta.tintaTenue)),
            selectedItemBuilder: (_) => [
              for (final m in marcas) Text(m.nombre, overflow: TextOverflow.ellipsis),
            ],
            items: [
              for (final m in marcas)
                DropdownMenuItem(value: m.nombre, child: Text(m.etiqueta, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => b.marca = v),
          ),
          if (enStock != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Text(
                enStock == 0 ? 'Sin stock' : '$enStock pallets en stock',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: enStock == 0 ? Paleta.tintaTenue : Paleta.azul,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filaCalibre(_BloqueEdit b, String c, {required bool ultima}) {
    final lista = b.pallets[c]!;
    return Container(
      constraints: const BoxConstraints(minHeight: 27),
      decoration: BoxDecoration(
        border: Border(bottom: ultima ? BorderSide.none : BorderSide(color: Paleta.bordeSuave)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _wCalibre,
            child: Text(c, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Paleta.tinta)),
          ),
          SizedBox(
            width: _wCant,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: TextField(
                controller: b.cant[c],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: _estiloCelda.copyWith(fontWeight: FontWeight.w800, fontFeatures: cifrasTabulares),
                decoration: _decoPlana('', centrado: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          SizedBox(
            width: _wTam,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: TextField(
                controller: b.tam[c],
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(fontSize: 12, color: Paleta.tintaSuave, fontWeight: FontWeight.w600),
                decoration: _decoPlana('STD', centrado: true),
              ),
            ),
          ),
          SizedBox(
            width: _wPallet,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Wrap(
                spacing: 3,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final p in lista)
                    InputChip(
                      label: Text(p, style: TextStyle(fontSize: 11, color: Paleta.azul, fontWeight: FontWeight.w800)),
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.only(left: 4),
                      padding: EdgeInsets.zero,
                      backgroundColor: Paleta.suave(Paleta.azul, 0.08),
                      side: BorderSide(color: Paleta.azul.withValues(alpha: 0.3)),
                      deleteIconColor: Paleta.azul,
                      onDeleted: () => setState(() => _sacarPallet(b, c, p)),
                    ),
                  SizedBox(
                    width: lista.isEmpty ? _wPallet - 12 : 92,
                    child: Focus(
                      onFocusChange: (tiene) {
                        if (!tiene) setState(() => _confirmarTipeo(b, c)); // al salir también se agrega
                      },
                      child: TextField(
                        controller: b.palletIn[c],
                        onSubmitted: (_) => setState(() => _confirmarTipeo(b, c)),
                        style: const TextStyle(fontSize: 12),
                        decoration: _decoPlana(lista.isEmpty ? 'N° o rango 200-205 + Enter' : '+ pallet'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Calibres guardados que no están en la grilla: se muestran y se guardan tal cual.
  Widget _filaFuera(_BloqueEdit b) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: Paleta.suave(Paleta.oro, 0.08),
      border: Border(top: BorderSide(color: Paleta.bordeSuave)),
    ),
    child: Text(
      'Otros calibres (se conservan): ${b.fuera.map((c) => '${c.calibre}: ${c.cantidad}').join(' · ')}',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Paleta.oro),
    ),
  );

  Widget _celdaVuelo(_BloqueEdit b) {
    final lista = _vuelosDe(b);
    var idx = lista.indexWhere((v) => _vueloDe(v) == b.vuelo && _awbDe(v) == b.awb);
    final plazasDelVuelo = lista.where((v) => _vueloDe(v) == b.vuelo).length;
    // Programa viejo sin AWB: si el vuelo tiene una sola plaza es ésa; si tiene varias, hay que elegir.
    if (idx < 0 && b.awb.isEmpty && plazasDelVuelo == 1) idx = lista.indexWhere((v) => _vueloDe(v) == b.vuelo);
    final faltaAwb = idx < 0 && b.vuelo.isNotEmpty && b.awb.isEmpty && plazasDelVuelo > 1;
    final deOtraFecha = b.vuelo.isNotEmpty && !_vueloEnFecha(b.vuelo);
    final deOtroForwarder = b.vuelo.isNotEmpty && idx < 0 && !deOtraFecha && !faltaAwb;
    final awbElegida = idx >= 0 ? _awbDe(lista[idx]) : b.awb;
    final (capacidad, usados) = b.vuelo.isEmpty ? (0, 0) : _cupoPlaza(b.vuelo, awbElegida);
    final excedido = capacidad > 0 && usados > capacidad;
    // Vuelo con varias plazas: además se muestra el total del vuelo.
    final (capVuelo, usadosVuelo) = b.vuelo.isEmpty || plazasDelVuelo < 2 ? (0, 0) : _cupoVuelo(b.vuelo);
    String fin(String awb) => awb.length > 4 ? awb.substring(awb.length - 4) : awb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 4, 3, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            initialValue: idx >= 0 ? idx : null,
            key: ValueKey('vue-${b.clave}-$_fecha-${b.forwarder}-${b.vuelo}-${b.awb}'),
            isExpanded: true,
            isDense: true,
            style: _estiloCelda.copyWith(fontWeight: FontWeight.w800),
            decoration: _decoPlana(''),
            hint: Text(
              faltaAwb
                  ? '${b.vuelo}: elegí la AWB'
                  : b.vuelo.isNotEmpty && idx < 0 ? b.vuelo : (lista.isEmpty ? (_vuelosDia.isEmpty ? 'Sin vuelos ese día' : 'Sin vuelos de ${b.forwarder}') : 'Vuelo…'),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: idx < 0 && b.vuelo.isNotEmpty ? Paleta.oro : Paleta.tintaTenue,
                  fontWeight: idx < 0 && b.vuelo.isNotEmpty ? FontWeight.w800 : FontWeight.w400),
            ),
            selectedItemBuilder: (_) => [
              for (final v in lista)
                Text(
                  // Mismo vuelo con varias plazas: se distinguen por los últimos dígitos de la AWB.
                  lista.where((o) => _vueloDe(o) == _vueloDe(v)).length > 1 && _awbDe(v).isNotEmpty
                      ? '${_vueloDe(v)} ·${fin(_awbDe(v))}'
                      : _vueloDe(v),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
            items: [
              for (final (j, v) in lista.indexed)
                DropdownMenuItem(
                  value: j,
                  child: Builder(builder: (_) {
                    final (cap, usa) = _cupoPlaza(_vueloDe(v), _awbDe(v));
                    final libres = cap - usa;
                    return Text(
                      '${_vueloDe(v)} · ${_awbDe(v).isEmpty ? 'sin AWB' : 'AWB ${_awbDe(v)}'}'
                      ' · ${txt(v['destino']).isEmpty ? '-' : txt(v['destino'])}'
                      ' · ${cap > 0 ? '$libres de $cap libres' : '${numDe(v['pcs']).toInt()} pl'}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cap > 0 && libres <= 0 ? Paleta.peligro : null),
                    );
                  }),
                ),
            ],
            onChanged: (j) => _elegirVuelo(b, j == null || j >= lista.length ? null : lista[j]),
          ),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.place_outlined, size: 14, color: Paleta.tintaSuave),
              ),
              Expanded(
                child: TextField(
                  controller: b.destino,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Paleta.tintaSuave),
                  textCapitalization: TextCapitalization.characters,
                  decoration: _decoPlana('Destino').copyWith(contentPadding: const EdgeInsets.fromLTRB(4, 5, 4, 5)),
                ),
              ),
            ],
          ),
          if (b.horaVuelo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('ETD ${fechaHoraCorta(b.horaVuelo)}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Paleta.tintaSuave)),
            ),
          if (idx >= 0 && _awbDe(lista[idx]).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 1, right: 4),
              child: Tooltip(
                message: 'AWB: ${_awbDe(lista[idx])}'
                    '${numDe(lista[idx]['_awb_repetidas']) > 0 ? '\n${numDe(lista[idx]['_awb_repetidas']).toInt()} fila(s) con la misma AWB no se cuentan' : ''}',
                child: Text(
                  'AWB ${_awbDe(lista[idx])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Paleta.tintaSuave),
                ),
              ),
            ),
          if (deOtraFecha || deOtroForwarder || faltaAwb)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Text(
                  faltaAwb
                      ? 'Tiene $plazasDelVuelo plazas: elegí la AWB'
                      : deOtraFecha ? 'No sale ese día: cambialo' : 'Otro forwarder o AWB que ya no está',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Paleta.oro)),
            )
          else if (b.vuelo.isNotEmpty && capacidad > 0) ...[
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2, right: 6),
              child: Text(
                '${awbElegida.isEmpty ? '' : 'AWB '}$usados / $capacidad pl${excedido ? ' · excedido' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: excedido ? Paleta.peligro : Paleta.verde,
                  fontFeatures: cifrasTabulares,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 3, 6, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (usados / capacidad).clamp(0, 1).toDouble(),
                  minHeight: 4,
                  color: excedido ? Paleta.peligro : Paleta.verde,
                  backgroundColor: Paleta.superficieHundida,
                ),
              ),
            ),
            if (capVuelo > 0)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 2, right: 6),
                child: Text(
                  'Vuelo: $usadosVuelo / $capVuelo pl ($plazasDelVuelo AWB)',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: usadosVuelo > capVuelo ? Paleta.peligro : Paleta.tintaSuave,
                    fontFeatures: cifrasTabulares,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _piePlanilla(int total) {
    final porCamion = <String, int>{};
    for (final b in _bloques) {
      porCamion[b.camion] = (porCamion[b.camion] ?? 0) + b.total;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: Paleta.superficieSuave,
        border: Border(top: BorderSide(color: _lineaFuerte, width: 1.2)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Paleta.verdeOscuro),
                onPressed: _bloques.length >= maxBloquesPrograma ? null : _agregarBloque,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Agregar bloque (${_bloques.length}/$maxBloquesPrograma)'),
              ),
              if (_bloques.length > 1)
                OutlinedButton.icon(
                  onPressed: _aplicarVueloATodos,
                  icon: const Icon(Icons.flight_takeoff_rounded, size: 16),
                  label: Text('Vuelo del #${_activo + 1} a todos'),
                ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_conCamion)
                for (final MapEntry(key: camion, value: n) in porCamion.entries)
                  Pastilla(texto: '$camion · $n pl', color: Paleta.verde, icono: Icons.local_shipping_rounded),
              const SizedBox(width: 6),
              Text('TOTAL ${fmtNum(total)} PALLETS',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Paleta.verdeTitulo)),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Panel de stock ───────────────────────────

  /// Pestaña tipo carpeta de archivero que abre y cierra el stock.
  Widget _solapaStock({required bool vertical}) {
    final b = _bloqueActivo;
    final marca = _soloMarcaBloque ? b.marca : null;
    final n = _cargandoStock ? null : _stock.where((p) => marca == null || _esDeMarca(p, marca)).length;
    final texto = 'STOCK${marca == null ? '' : ' · $marca'}${n == null ? '' : ' · $n'}';
    final contenido = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_stockAbierto ? Icons.folder_open_rounded : Icons.folder_rounded, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(texto, style: _estiloEncabezado.copyWith(fontSize: 11.5)),
        const SizedBox(width: 4),
        Icon(
          vertical
              ? (_stockAbierto ? Icons.chevron_right_rounded : Icons.chevron_left_rounded)
              : (_stockAbierto ? Icons.expand_less_rounded : Icons.expand_more_rounded),
          size: 16,
          color: Colors.white,
        ),
      ],
    );
    final radio = vertical
        ? const BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10))
        : const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10));
    return Padding(
      padding: EdgeInsets.only(top: vertical ? 40 : 0),
      child: Material(
        color: _stockAbierto ? Paleta.verdeOscuro : Paleta.verde,
        borderRadius: radio,
        elevation: 2,
        child: InkWell(
          borderRadius: radio,
          onTap: () => setState(() => _stockAbierto = !_stockAbierto),
          child: Padding(
            padding: vertical
                ? const EdgeInsets.symmetric(horizontal: 6, vertical: 14)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: vertical ? RotatedBox(quarterTurns: 1, child: contenido) : contenido,
          ),
        ),
      ),
    );
  }

  Widget _panelStock(Map<String, (int, String)> enPlanilla, double alto) {
    final b = _bloqueActivo;
    final marca = _soloMarcaBloque ? b.marca : null;
    final q = _buscarStock.text.trim().toLowerCase();

    final deMarca = [for (final p in _stock) if (marca == null || _esDeMarca(p, marca)) p];
    final cantProgramados = deMarca.where((p) => _programados.containsKey(p.pallet)).length;
    // Base del resumen: marca + búsqueda + programados (sin los filtros de calibre y color, que salen de él).
    final base = [
      for (final p in deMarca)
        if ((q.isEmpty || p.busqueda.contains(q)) &&
            (!_ocultarProgramados || !_programados.containsKey(p.pallet) || enPlanilla.containsKey(p.pallet)))
          p,
    ];
    final visibles = [
      for (final p in base)
        if ((_filtroCalibre == null || p.calibresGrilla.contains(_filtroCalibre)) &&
            (_filtroColor == null || p.colores.contains(_filtroColor)))
          p,
    ];
    final cajas = visibles.fold(0, (s, p) => s + p.cajas);

    final Widget lista;
    if (_cargandoStock) {
      lista = const Center(child: CircularProgressIndicator());
    } else if (_errorStock != null) {
      lista = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, color: Paleta.peligro),
            const SizedBox(height: 6),
            Text('No se pudo leer el stock: $_errorStock',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Paleta.peligro)),
            TextButton.icon(
              onPressed: _cargarStock,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else if (visibles.isEmpty) {
      lista = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _stock.isEmpty
                ? 'No hay pallets en stock.'
                : deMarca.isEmpty
                    ? 'Sin stock de ${b.marca}. Probá con "Todas".'
                    : 'Ningún pallet coincide con el filtro.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Paleta.tintaTenue),
          ),
        ),
      );
    } else {
      lista = ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        itemCount: visibles.length,
        itemBuilder: (_, i) => _tarjetaStock(visibles[i], enPlanilla, mostrarMarca: marca == null),
      );
    }

    return Container(
      height: alto,
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _lineaFuerte, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Paleta.verdeOscuro,
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('STOCK DE PALLETS', style: _estiloEncabezado.copyWith(fontSize: 12.5))),
                if (_stockOffline)
                  const Tooltip(
                    message: 'Sin conexión: copia guardada en este equipo',
                    child: Icon(Icons.cloud_off_rounded, color: Colors.white, size: 16),
                  ),
                IconButton(
                  tooltip: 'Actualizar stock',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  onPressed: _cargandoStock ? null : _cargarStock,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 11.5, color: Paleta.tintaSuave),
                    children: [
                      const TextSpan(text: 'Tocá un pallet para volcarlo al '),
                      TextSpan(
                        text: 'bloque #${_activo + 1}${b.cliente == null ? '' : ' · ${b.cliente}'}',
                        style: TextStyle(fontWeight: FontWeight.w800, color: Paleta.verde),
                      ),
                      const TextSpan(text: ', en el renglón de su calibre.'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    selectedBackgroundColor: Paleta.verde,
                    selectedForegroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(b.marca == null ? 'Marca del bloque' : b.marca!, overflow: TextOverflow.ellipsis),
                    ),
                    const ButtonSegment(value: false, label: Text('Todas las marcas')),
                  ],
                  selected: {_soloMarcaBloque},
                  onSelectionChanged: (s) => setState(() => _soloMarcaBloque = s.first),
                ),
                if (_soloMarcaBloque && b.marca == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('El bloque no tiene marca: se ve todo el stock (al volcar toma la del pallet).',
                        style: TextStyle(fontSize: 11, color: Paleta.oro, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _buscarStock,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Buscar pallet, variedad, productor, cámara…',
                    hintStyle: TextStyle(fontSize: 12, color: Paleta.tintaTenue),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _buscarStock.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () => setState(_buscarStock.clear),
                          ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 6),
                if (!_cargandoStock && base.isNotEmpty) _resumenStock(base),
                if (_filtroCalibre != null || _filtroColor != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (_filtroCalibre != null)
                          InputChip(
                            label: Text('Calibre ${_filtroCalibre!.isEmpty ? 'otros' : _filtroCalibre}',
                                style: const TextStyle(fontSize: 11)),
                            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onDeleted: () => setState(() => _filtroCalibre = null),
                          ),
                        if (_filtroColor != null)
                          InputChip(
                            label: Text('Color $_filtroColor', style: const TextStyle(fontSize: 11)),
                            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onDeleted: () => setState(() => _filtroColor = null),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text('${fmtNum(visibles.length)} pallets · ${fmtNum(cajas)} cajas',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Paleta.tinta)),
                    ),
                    if (cantProgramados > 0)
                      FilterChip(
                        label: Text('Ocultar programados ($cantProgramados)', style: const TextStyle(fontSize: 11)),
                        selected: _ocultarProgramados,
                        visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onSelected: (v) => setState(() => _ocultarProgramados = v),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _linea),
          Expanded(child: Container(color: Paleta.superficieSuave, child: lista)),
        ],
      ),
    );
  }

  /// Resumen del stock: pallets y cajas por calibre (filas) y color (columnas), con totales.
  /// Tocar un calibre, un color o una celda filtra la lista.
  Widget _resumenStock(List<PalletStock> base) {
    final pallets = <(String, String), Set<String>>{};
    final cajas = <(String, String), int>{};
    final palletsCal = <String, Set<String>>{};
    final cajasCal = <String, int>{};
    final palletsCol = <String, Set<String>>{};
    final cajasCol = <String, int>{};
    for (final p in base) {
      for (final d in p.detalle) {
        final k = (d.calibre, d.color);
        pallets.putIfAbsent(k, () => {}).add(p.pallet);
        cajas[k] = (cajas[k] ?? 0) + d.cajas;
        palletsCal.putIfAbsent(d.calibre, () => {}).add(p.pallet);
        cajasCal[d.calibre] = (cajasCal[d.calibre] ?? 0) + d.cajas;
        palletsCol.putIfAbsent(d.color, () => {}).add(p.pallet);
        cajasCol[d.color] = (cajasCol[d.color] ?? 0) + d.cajas;
      }
    }
    final filas = [
      for (final c in calibresPrograma) if (palletsCal.containsKey(c)) c,
      if (palletsCal.containsKey('')) '',
    ];
    final colores = cajasCol.keys.toList()..sort((a, b) => cajasCol[b]!.compareTo(cajasCol[a]!));
    final totalCajas = base.fold(0, (s, p) => s + p.cajas);

    const wRotulo = 50.0;
    const wCol = 64.0;
    const alto = 32.0;

    Widget valor(int nPallets, int nCajas, {bool fuerte = false, bool sel = false}) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$nPallets pl',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: sel ? Paleta.verdeOscuro : (fuerte ? Paleta.tinta : Paleta.tinta),
              fontFeatures: cifrasTabulares,
            )),
        Text('${fmtNum(nCajas)} cj',
            style: TextStyle(fontSize: 9.5, color: Paleta.tintaSuave, fontFeatures: cifrasTabulares)),
      ],
    );

    Widget celda({
      required double ancho,
      required Widget child,
      VoidCallback? onTap,
      Color? fondo,
      Alignment alineacion = Alignment.centerRight,
    }) =>
        InkWell(
          onTap: onTap,
          child: Container(
            width: ancho,
            height: alto,
            alignment: alineacion,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: fondo,
              border: Border(right: BorderSide(color: Paleta.bordeSuave), bottom: BorderSide(color: Paleta.bordeSuave)),
            ),
            child: child,
          ),
        );

    Color? fondoDe(String? cal, String? col) {
      final selCal = _filtroCalibre != null && cal == _filtroCalibre;
      final selCol = _filtroColor != null && col == _filtroColor;
      if ((selCal && (col == null || _filtroColor == null || selCol)) ||
          (selCol && (cal == null || _filtroCalibre == null || selCal))) {
        return Paleta.suave(Paleta.verde, 0.16);
      }
      return null;
    }

    final encabezado = Row(
      children: [
        celda(
          ancho: wRotulo,
          alineacion: Alignment.centerLeft,
          fondo: Paleta.superficieHundida,
          child: Text('CAL.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Paleta.tintaSuave)),
        ),
        for (final col in colores)
          celda(
            ancho: wCol,
            alineacion: Alignment.center,
            fondo: fondoDe(null, col) ?? Paleta.superficieHundida,
            onTap: () => setState(() => _filtroColor = _filtroColor == col ? null : col),
            child: Text(col,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Paleta.terracota)),
          ),
        if (colores.length > 1)
          celda(
            ancho: wCol,
            alineacion: Alignment.center,
            fondo: Paleta.superficieHundida,
            child: Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Paleta.tinta)),
          ),
      ],
    );

    Widget fila(String cal) => Row(
      children: [
        celda(
          ancho: wRotulo,
          alineacion: Alignment.centerLeft,
          fondo: fondoDe(cal, null) ?? Paleta.superficieSuave,
          onTap: () => setState(() => _filtroCalibre = _filtroCalibre == cal ? null : cal),
          child: Text(cal.isEmpty ? 'Otros' : cal,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: cal.isEmpty ? Paleta.oro : Paleta.verde)),
        ),
        for (final col in colores)
          celda(
            ancho: wCol,
            fondo: fondoDe(cal, col),
            onTap: pallets.containsKey((cal, col))
                ? () => setState(() {
                      final yaElegida = _filtroCalibre == cal && _filtroColor == col;
                      _filtroCalibre = yaElegida ? null : cal;
                      _filtroColor = yaElegida ? null : col;
                    })
                : null,
            child: pallets.containsKey((cal, col))
                ? valor(pallets[(cal, col)]!.length, cajas[(cal, col)]!,
                    sel: _filtroCalibre == cal && _filtroColor == col)
                : Text('—', style: TextStyle(fontSize: 11, color: Paleta.tintaTenue)),
          ),
        if (colores.length > 1)
          celda(
            ancho: wCol,
            fondo: Paleta.superficieSuave,
            child: valor(palletsCal[cal]!.length, cajasCal[cal]!, fuerte: true),
          ),
      ],
    );

    final pie = Row(
      children: [
        celda(
          ancho: wRotulo,
          alineacion: Alignment.centerLeft,
          fondo: Paleta.superficieHundida,
          child: Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Paleta.tinta)),
        ),
        for (final col in colores)
          celda(
            ancho: wCol,
            fondo: Paleta.superficieHundida,
            child: valor(palletsCol[col]!.length, cajasCol[col]!, fuerte: true),
          ),
        if (colores.length > 1)
          celda(
            ancho: wCol,
            fondo: Paleta.suave(Paleta.verde, 0.12),
            child: valor(base.length, totalCajas, fuerte: true, sel: true),
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Paleta.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _resumenAbierto = !_resumenAbierto),
            child: Container(
              color: Paleta.superficieSuave,
              padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
              child: Row(
                children: [
                  Icon(Icons.grid_on_rounded, size: 14, color: Paleta.verde),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Por calibre y color · ${fmtNum(base.length)} pl · ${fmtNum(totalCajas)} cj',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Paleta.tinta),
                    ),
                  ),
                  Icon(_resumenAbierto ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 18, color: Paleta.tintaSuave),
                ],
              ),
            ),
          ),
          if (_resumenAbierto)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [encabezado, for (final c in filas) fila(c), pie],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tarjetaStock(PalletStock p, Map<String, (int, String)> enPlanilla, {required bool mostrarMarca}) {
    final ubicacion = enPlanilla[p.pallet];
    final enActivo = ubicacion != null && ubicacion.$1 == _activo;
    final otroPrograma = _programados[p.pallet];
    final String? nota;
    final Color colorNota;
    if (enActivo) {
      nota = 'En el bloque #${ubicacion!.$1 + 1} · calibre ${ubicacion.$2} · tocá para quitarlo';
      colorNota = Paleta.verde;
    } else if (ubicacion != null) {
      nota = 'Ya está en el bloque #${ubicacion.$1 + 1} (calibre ${ubicacion.$2})';
      colorNota = Paleta.azul;
    } else if (otroPrograma != null) {
      nota = 'Ya programado en el N° $otroPrograma';
      colorNota = Paleta.oro;
    } else if (p.calibreGrilla == null) {
      nota = 'Calibre fuera de la grilla: elegí el renglón con ⋮';
      colorNota = Paleta.oro;
    } else {
      nota = null;
      colorNota = Paleta.tintaSuave;
    }
    final linea2 = [p.variedad, p.categoria, p.envase].where((s) => s.isNotEmpty).join(' · ');
    final linea3 = [
      if (p.produccion.isNotEmpty) 'Prod. ${diaMes(p.produccion)}',
      if (p.camara.isNotEmpty) 'Cám. ${p.camara}',
      if (p.romaneo.isNotEmpty) 'Rom. ${p.romaneo}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: enActivo ? Paleta.suave(Paleta.verde, 0.12) : Paleta.superficie,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _tocarPallet(p),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 0, 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: enActivo ? Paleta.verde : (ubicacion != null || otroPrograma != null ? colorNota.withValues(alpha: 0.5) : Paleta.borde),
                width: enActivo ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    enActivo ? Icons.check_circle_rounded : Icons.inventory_2_outlined,
                    size: 18,
                    color: enActivo ? Paleta.verde : Paleta.tintaSuave,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(p.pallet,
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Paleta.tinta)),
                          ),
                          Text('${fmtNum(p.cajas)} cj',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Paleta.tinta,
                                  fontFeatures: cifrasTabulares)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 4,
                        runSpacing: 3,
                        children: [
                          for (final (cal, cj) in p.calibres)
                            Pastilla(
                              texto: p.mixto ? '$cal · $cj' : cal,
                              color: calibreDeGrilla(cal) == null ? Paleta.oro : Paleta.verde,
                            ),
                          for (final col in p.colores)
                            if (col != 'S/COLOR') Pastilla(texto: col, color: Paleta.terracota),
                          if (mostrarMarca && p.marca.isNotEmpty) Pastilla(texto: p.marca, color: Paleta.azul),
                        ],
                      ),
                      if (linea2.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(linea2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Paleta.tintaSuave, fontWeight: FontWeight.w600)),
                        ),
                      if (linea3.isNotEmpty)
                        Text(linea3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, color: Paleta.tintaTenue)),
                      if (nota != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(nota, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: colorNota)),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Volcar a un calibre',
                  icon: Icon(Icons.more_vert_rounded, size: 18, color: Paleta.tintaSuave),
                  itemBuilder: (_) => [
                    for (final c in calibresPrograma)
                      PopupMenuItem(
                        value: c,
                        enabled: !(enActivo && ubicacion?.$2 == c),
                        child: Text(c == p.calibreGrilla ? 'Volcar a $c (su calibre)' : 'Volcar a $c'),
                      ),
                  ],
                  onSelected: (c) => _volcarPallet(p, c),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════ Visor del programa ═══════════════════════════

enum AccionDetalle { editar, copiar }

/// Detalle de un programa (renglones por calibre) con PDF, copiar y editar.
Future<AccionDetalle?> dialogoDetallePrograma(BuildContext context, DatosPrograma d, ProgramaAgrupado p) {
  return showDialog<AccionDetalle>(
    context: context,
    builder: (context) {
      final ancha = MediaQuery.sizeOf(context).width >= 900;
      final renglones = p.renglones;
      const cols = [
        (2, 'Camión', false),
        (3, 'Cliente', false),
        (2, 'Marca', false),
        (1, 'Calibre', false),
        (1, 'Cant.', true),
        (1, 'Tamaño', false),
        (3, 'N° pallets', false),
        (2, 'Destino', false),
        (2, 'Vuelo', false),
        (2, 'Salida empaque', false),
      ];
      Widget t(String s, {bool negrita = false, Color? color}) => Text(
        s,
        style: TextStyle(fontSize: 12.5, fontWeight: negrita ? FontWeight.w700 : FontWeight.w400, color: color ?? Paleta.tinta),
      );
      return MarcoDialogo(
        titulo: 'Programa ${p.nro}',
        subtitulo: 'Fecha ${formatearFecha(p.fecha)} · ${p.camiones.length} camión(es) · ${fmtNum(p.pallets)} pallets'
            ' · Salida ${salidaLegible(p.salidaEmpaque)}',
        icono: Icons.event_note_rounded,
        tono: Paleta.verde,
        anchoMaximo: 1100,
        acciones: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          OutlinedButton.icon(
            onPressed: () => exportarProgramaPdf(context, d, p),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: const Text('Exportar PDF'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, AccionDetalle.copiar),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar programa'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, AccionDetalle.editar),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Editar programa'),
          ),
        ],
        child: ancha
            ? Column(
                children: [
                  Container(
                    height: 36,
                    decoration: decoFilaTabla(primera: true),
                    child: FilaTabla(celdas: [for (final (f, s, der) in cols) (f, textoEncabezado(s), der)]),
                  ),
                  for (final (i, r) in renglones.indexed)
                    ContenedorFila(
                      decoration: decoFilaTabla(ultima: i == renglones.length - 1),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: FilaTabla(
                        celdas: [
                          (2, Pastilla(texto: txt(r['camion_no']).isEmpty ? 'S/D' : txt(r['camion_no']), color: Paleta.verde), false),
                          (3, t(txt(r['cliente']), negrita: true), false),
                          (2, t(txt(r['marca'])), false),
                          (1, t(txt(r['calibre']), negrita: true), false),
                          (1, t(fmtNum(numDe(r['cantidad'])), negrita: true), true),
                          (1, t(txt(r['tamano']).isEmpty ? 'STD' : txt(r['tamano']), color: Paleta.tintaSuave), false),
                          (3, t(txt(r['nro_pallet']).isEmpty ? '-' : txt(r['nro_pallet']), color: Paleta.azul), false),
                          (2, t(txt(r['destino']).isEmpty ? '-' : txt(r['destino'])), false),
                          (2, t(txt(r['vuelo']).isEmpty ? '-' : txt(r['vuelo']), negrita: true), false),
                          (2, t(salidaLegible(r['salida_empaque']), color: Paleta.tintaSuave), false),
                        ],
                      ),
                    ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final r in renglones)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: decoTarjeta(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Pastilla(texto: txt(r['camion_no']).isEmpty ? 'S/D' : txt(r['camion_no']), color: Paleta.verde),
                              const SizedBox(width: 8),
                              Expanded(child: t(txt(r['cliente']), negrita: true)),
                              t('${fmtNum(numDe(r['cantidad']))} pl', negrita: true),
                            ],
                          ),
                          const SizedBox(height: 4),
                          t('${txt(r['marca'])} · calibre ${txt(r['calibre'])} · ${txt(r['tamano']).isEmpty ? 'STD' : txt(r['tamano'])}',
                              color: Paleta.tintaSuave),
                          t('${txt(r['destino']).isEmpty ? '-' : txt(r['destino'])} · vuelo ${txt(r['vuelo']).isEmpty ? '-' : txt(r['vuelo'])}'
                              ' · salida ${salidaLegible(r['salida_empaque'])}', color: Paleta.tintaSuave),
                          if (txt(r['nro_pallet']).isNotEmpty) t('Pallets: ${txt(r['nro_pallet'])}', color: Paleta.azul),
                        ],
                      ),
                    ),
                ],
              ),
      );
    },
  );
}
