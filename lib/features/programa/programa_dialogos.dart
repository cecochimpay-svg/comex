import 'package:flutter/material.dart';

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

class _EditorProgramaState extends State<_EditorPrograma> {
  DatosPrograma get d => widget.datos;
  AperturaPrograma get a => widget.apertura;

  late final TextEditingController _nro = TextEditingController(text: a.nro);
  late String _fecha = a.fecha;
  late String _salida = a.salida;

  late final List<Bloque> _bloques = [...a.bloques];
  late final List<String> _camiones;
  late String _camion;

  String? _cliente;
  String? _marca;
  int? _vueloIdx;
  List<Fila> _vuelosDia = const [];
  String _destino = '';
  String _horaVuelo = '';
  String _consignatario = '';

  final _cant = {for (final c in calibresPrograma) c: TextEditingController()};
  final _tam = {for (final c in calibresPrograma) c: TextEditingController(text: 'STD')};
  final _pallets = {for (final c in calibresPrograma) c: <String>[]};
  final _palletIn = {for (final c in calibresPrograma) c: TextEditingController()};

  /// ids de Supabase de los calibres del bloque que se volvió a abrir para editar (así no se duplican).
  Map<String, int> _idsEdicion = {};

  String? _ayuda;
  (String, bool)? _mensaje; // (texto, es error)
  bool _guardando = false;

  bool get _edicion => a.modo == ModoPrograma.editar;

  @override
  void initState() {
    super.initState();
    final camiones = {for (final b in _bloques) b.camion}.toList()..sort();
    _camiones = camiones.isEmpty ? [nombreCamion(1)] : camiones;
    _camion = _camiones.first;
    _filtrarVuelos();
    if (a.avisoInicial != null) _mensaje = (a.avisoInicial!, false);
  }

  @override
  void dispose() {
    _nro.dispose();
    for (final m in [_cant, _tam, _palletIn]) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _avisar(String texto, {bool error = false}) => setState(() => _mensaje = (texto, error));

  // ── Vuelo del día y cupo ──

  Fila? get _vuelo => _vueloIdx == null || _vueloIdx! >= _vuelosDia.length ? null : _vuelosDia[_vueloIdx!];

  void _filtrarVuelos() {
    _vuelosDia = d.vuelosDelDia(_fecha);
    _vueloIdx = null;
    _destino = '';
    _horaVuelo = '';
  }

  void _elegirVuelo(int? idx) => setState(() {
    _vueloIdx = idx;
    final v = _vuelo;
    if (v == null) {
      _destino = '';
      _horaVuelo = '';
      return;
    }
    if (_destino.isEmpty) _destino = txt(v['destino']);
    final hora = '${txt(v['fecha_etd1'])} ${txt(v['hora_etd1'])}'.trim();
    _horaVuelo = hora.isEmpty ? 'S/D' : hora;
  });

  String _vueloDe(Fila v) => txt(v['vuelo']).isEmpty ? '-' : txt(v['vuelo']);

  bool _vueloEnFecha(String vuelo) => _vuelosDia.any((v) => _vueloDe(v) == vuelo);

  int get _tipeado => _cant.values.fold(0, (s, c) => s + (int.tryParse(c.text.trim()) ?? 0));

  /// (capacidad, usados, libres) del vuelo elegido.
  (int, int, int) get _cupo {
    final v = _vuelo;
    if (v == null) return (0, 0, 0);
    final capacidad = numDe(v['pcs']).toInt();
    final guardados = d.palletsGuardadosEnVuelo(txt(v['vuelo']), _fecha,
        excluirPrograma: _edicion ? a.programaOriginal : null);
    final enBloques = _bloques.where((b) => b.vuelo == txt(v['vuelo'])).fold(0, (s, b) => s + b.total);
    final usados = guardados + enBloques + _tipeado;
    return (capacidad, usados, capacidad - usados);
  }

  // ── Cliente / consignatario ──

  void _elegirCliente(String? cliente) => setState(() {
    _cliente = cliente;
    _consignatario = '';
    final lista = d.clientes[cliente] ?? const <OpcionConsignatario>[];
    if (lista.isNotEmpty) _elegirConsignatario(lista.first); // se preselecciona el primero
  });

  void _elegirConsignatario(OpcionConsignatario o) {
    _consignatario = o.consignatario;
    if (o.destino.isNotEmpty) _destino = o.destino;
  }

  // ── Pallets por calibre ──

  void _agregarPallets(String calibre) {
    final texto = _palletIn[calibre]!.text.trim();
    if (texto.isEmpty) return;
    setState(() {
      final lista = _pallets[calibre]!;
      for (final p in parsearRangoPallets(texto)) {
        if (!lista.contains(p)) lista.add(p);
      }
      _palletIn[calibre]!.clear();
      _cant[calibre]!.text = '${lista.length}'; // la cantidad sigue a los pallets cargados
    });
  }

  void _quitarPallet(String calibre, String p) => setState(() {
    _pallets[calibre]!.remove(p);
    if (_pallets[calibre]!.isNotEmpty) _cant[calibre]!.text = '${_pallets[calibre]!.length}';
  });

  void _limpiarBloque() {
    for (final c in calibresPrograma) {
      _cant[c]!.clear();
      _pallets[c]!.clear();
      _palletIn[c]!.clear();
    }
    _idsEdicion = {};
    _ayuda = null;
  }

  bool get _hayBloqueSinAgregar => _tipeado > 0 || _idsEdicion.isNotEmpty;

  // ── Bloques ──

  void _agregarBloque() {
    if (_bloques.length >= maxBloquesPrograma) {
      return _avisar('Límite de $maxBloquesPrograma bloques alcanzado para este programa.');
    }
    final v = _vuelo;
    if (v == null) return _avisar('Seleccioná un vuelo del día.', error: true);
    if (_cliente == null || _marca == null) {
      return _avisar('Seleccioná Cliente y Marca antes de añadir el bloque.', error: true);
    }

    final items = <CalibreBloque>[];
    for (final c in calibresPrograma) {
      final cant = int.tryParse(_cant[c]!.text.trim()) ?? 0;
      if (cant <= 0) continue;
      items.add(CalibreBloque(
        calibre: c,
        cantidad: cant,
        tamano: _tam[c]!.text.trim().isEmpty ? 'STD' : _tam[c]!.text.trim(),
        nroPallet: _pallets[c]!.isEmpty ? null : _pallets[c]!.join(', '),
        id: _idsEdicion[c],
      ));
    }
    if (items.isEmpty) return _avisar('Ingresá la cantidad de pallets en al menos un calibre.', error: true);

    final total = items.fold(0, (s, c) => s + c.cantidad);
    final capacidad = numDe(v['pcs']).toInt();
    final yaAsignados = _bloques.where((b) => b.vuelo == txt(v['vuelo'])).fold(0, (s, b) => s + b.total);
    if (capacidad > 0 && yaAsignados + total > capacidad) {
      return _avisar('Supera los $capacidad pallets (PCS) del vuelo por ${yaAsignados + total - capacidad}.',
          error: true);
    }

    setState(() {
      _bloques.add(Bloque(
        idTemp: nuevoIdTemp(),
        camion: _camion.isEmpty ? 'S/D' : _camion,
        cliente: _cliente!,
        consignatario: _consignatario.isEmpty ? '-' : _consignatario,
        marca: _marca!,
        destino: _destino,
        vuelo: _vueloDe(v),
        horaSalidaVuelo: _horaVuelo,
        calibres: items,
      ));
      _limpiarBloque();
      _mensaje = ('Bloque #${_bloques.length} añadido a $_camion.', false);
    });
  }

  /// Devuelve un bloque ya añadido al formulario para modificarlo.
  Future<void> _editarBloque(Bloque b) async {
    if (_hayBloqueSinAgregar) {
      final ok = await confirmar(
        context,
        titulo: 'Bloque sin añadir',
        mensaje: 'Hay un bloque en el formulario que todavía no se añadió. Si seguís, se descarta. ¿Continuar?',
        textoOk: 'Continuar',
      );
      if (!ok || !mounted) return;
    }
    final avisos = <String>[];
    setState(() {
      _bloques.remove(b);
      if (!_camiones.contains(b.camion)) _camiones.add(b.camion);
      _camion = b.camion;

      _cliente = b.cliente;
      _consignatario = b.consignatario == '-' ? '' : b.consignatario;
      _marca = b.marca;

      final idx = _vuelosDia.indexWhere((v) => _vueloDe(v) == b.vuelo);
      _vueloIdx = idx >= 0 ? idx : null;
      final v = _vuelo;
      if (v != null) {
        final hora = '${txt(v['fecha_etd1'])} ${txt(v['hora_etd1'])}'.trim();
        _horaVuelo = hora.isEmpty ? 'S/D' : hora;
      } else {
        _horaVuelo = '';
        avisos.add('El vuelo ${b.vuelo} no corresponde a la fecha elegida: seleccioná otro.');
      }
      _destino = b.destino;

      _limpiarBloque();
      final fuera = <String>[];
      for (final c in b.calibres) {
        if (!calibresPrograma.contains(c.calibre)) {
          fuera.add(c.calibre);
          continue;
        }
        _pallets[c.calibre]!.addAll(
          (c.nroPallet ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
        );
        _cant[c.calibre]!.text = '${c.cantidad}';
        _tam[c.calibre]!.text = c.tamano.isEmpty ? 'STD' : c.tamano;
        if (c.id != null) _idsEdicion[c.calibre] = c.id!;
      }
      if (fuera.isNotEmpty) avisos.add('Calibres ${fuera.join(', ')} no están en la grilla y no se pueden editar acá.');
      _ayuda = 'Editando bloque de ${b.cliente} (${b.camion}): modificalo y volvé a añadirlo.';
      _mensaje = avisos.isEmpty ? null : (avisos.join(' '), fuera.isNotEmpty);
    });
  }

  void _aplicarVueloATodos() {
    final v = _vuelo;
    if (v == null) return _avisar('Elegí primero el vuelo en "Vuelo del día".', error: true);
    if (_bloques.isEmpty) return;
    final capacidad = numDe(v['pcs']).toInt();
    final total = _bloques.fold(0, (s, b) => s + b.total);
    final ocupado = d.palletsGuardadosEnVuelo(txt(v['vuelo']), _fecha,
        excluirPrograma: _edicion ? a.programaOriginal : null);
    if (capacidad > 0 && ocupado + total > capacidad) {
      return _avisar('No entra: el vuelo tiene ${capacidad - ocupado} pallets libres y los bloques suman $total.',
          error: true);
    }
    setState(() {
      for (final b in _bloques) {
        b.vuelo = _vueloDe(v);
        b.horaSalidaVuelo = _horaVuelo;
      }
      _mensaje = ('Vuelo ${txt(v['vuelo'])} aplicado a ${_bloques.length} bloque(s).', false);
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
      _filtrarVuelos(); // al cambiar la fecha se re-evalúan los vuelos de cada bloque
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

  // ── Guardar ──

  Future<void> _guardar() async {
    if (_bloques.isEmpty) return _avisar('Debés añadir al menos un bloque al programa.', error: true);
    final nro = _nro.text.trim();
    if (nro.isEmpty || _fecha.isEmpty) {
      return _avisar('Completá el N° de programa y la fecha de empaque.', error: true);
    }
    // Programa nuevo o copia: N° numérico correlativo (último + 1). En edición se respeta el que tenía
    // (los viejos son "PRG-…").
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
    if (_hayBloqueSinAgregar) {
      final ok = await confirmar(
        context,
        titulo: 'Bloque sin añadir',
        mensaje: 'Hay un bloque en el formulario que no se añadió. ¿Guardar el programa sin él?',
        textoOk: 'Guardar igual',
      );
      if (!ok || !mounted) return;
    }
    final raros = _bloques.where((b) => !_vueloEnFecha(b.vuelo)).length;
    if (raros > 0 && d.vuelos.isNotEmpty) {
      final ok = await confirmar(
        context,
        titulo: 'Vuelos de otra fecha',
        mensaje: '$raros bloque(s) tienen un vuelo que no sale el ${formatearFecha(_fecha)}. ¿Guardar igual?',
        textoOk: 'Guardar igual',
      );
      if (!ok || !mounted) return;
    }

    final renglones = renglonesAGuardar(
      bloques: _bloques,
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
      final sinColumna = omitidas.contains('consignatario')
          ? ' La nube no tiene la columna consignatario (migración 001): se guardó sin ella.'
          : '';
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

  // ── Pantalla ──

  @override
  Widget build(BuildContext context) {
    final titulo = switch (a.modo) {
      ModoPrograma.nuevo => 'Nuevo programa',
      ModoPrograma.editar => 'Editar programa ${a.programaOriginal}',
      ModoPrograma.copiar => 'Copia de ${a.programaOriginal}',
    };
    final total = _bloques.fold(0, (s, b) => s + b.total);
    return MarcoDialogo(
      titulo: titulo,
      subtitulo: '${_bloques.length} de $maxBloquesPrograma bloques · ${fmtNum(total)} pallets'
          '${_edicion ? ' · Edición' : a.modo == ModoPrograma.copiar ? ' · Copia' : ''}',
      icono: a.modo == ModoPrograma.editar ? Icons.edit_note_rounded : Icons.event_note_rounded,
      tono: Paleta.verde,
      anchoMaximo: 1240,
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
          final ancha = c.maxWidth >= 960;
          final izquierda = _columnaBloque();
          final derecha = _columnaLateral(total);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilaCampos([
                (
                  2,
                  _edicion
                      ? campoTexto(_nro, 'Programa N°', mayusculas: true)
                      : campoTexto(_nro, 'Programa N°', pista: d.siguienteNro, tipo: TipoCampo.entero),
                ),
                (2, _campoTocable('Fecha empaque', formatearFecha(_fecha), Icons.calendar_today_rounded, _elegirFecha)),
                (3, _campoTocable('Salida empaque', formatearFecha(_salida, conHora: true), Icons.schedule_rounded,
                    _elegirSalida)),
              ]),
              if (_mensaje != null) ...[const SizedBox(height: 12), _banner(_mensaje!.$1, _mensaje!.$2)],
              const SizedBox(height: 14),
              if (ancha)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: izquierda), const SizedBox(width: 14), SizedBox(width: 350, child: derecha)],
                )
              else ...[izquierda, const SizedBox(height: 14), derecha],
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

  Widget _campoTocable(String etiqueta, String valor, IconData icono, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: InputDecorator(
      decoration: decoCampo(etiqueta).copyWith(suffixIcon: Icon(icono, size: 18, color: Paleta.tintaSuave)),
      child: Text(valor, style: TextStyle(fontSize: 13.5, color: Paleta.tinta)),
    ),
  );

  // ── Columna izquierda: armado del bloque ──

  Widget _columnaBloque() {
    final opcionesCons = d.clientes[_cliente] ?? const <OpcionConsignatario>[];
    final clientes = [...d.nombresClientes, if (_cliente != null && !d.clientes.containsKey(_cliente)) _cliente!];
    final marcas = [
      ...d.marcas,
      if (_marca != null && !d.marcas.any((m) => m.nombre == _marca)) OpcionMarca(_marca!, _marca!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeccionForm(titulo: 'Camión', child: _selectorCamiones()),
        const SizedBox(height: 12),
        SeccionForm(
          titulo: 'Bloque',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilaCampos([
                (
                  1,
                  DropdownButtonFormField<String>(
                    initialValue: _cliente,
                    key: ValueKey('cli-$_cliente'),
                    isExpanded: true,
                    decoration: decoCampo('Cliente'),
                    hint: Text(clientes.isEmpty ? '— Sin clientes disponibles —' : '— Seleccionar cliente —'),
                    items: [for (final c in clientes) DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))],
                    onChanged: _elegirCliente,
                  ),
                ),
                (
                  1,
                  DropdownButtonFormField<String>(
                    initialValue: _marca,
                    key: ValueKey('mar-$_marca'),
                    isExpanded: true,
                    decoration: decoCampo('Marca'),
                    hint: const Text('— Seleccionar marca —'),
                    items: [
                      for (final m in marcas)
                        DropdownMenuItem(value: m.nombre, child: Text(m.etiqueta, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _marca = v),
                  ),
                ),
                (
                  1,
                  DropdownButtonFormField<int>(
                    initialValue: _vueloIdx,
                    key: ValueKey('vue-$_fecha-$_vueloIdx'),
                    isExpanded: true,
                    decoration: decoCampo('Vuelo del día'),
                    hint: Text(
                      _vuelosDia.isEmpty ? 'Sin vuelos para el ${formatearFecha(_fecha)}' : 'Seleccionar vuelo del día…',
                      overflow: TextOverflow.ellipsis,
                    ),
                    items: [
                      for (final (i, v) in _vuelosDia.indexed)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${txt(v['vuelo']).isEmpty ? 'S/V' : txt(v['vuelo'])} · ${txt(v['destino']).isEmpty ? '-' : txt(v['destino'])}'
                            ' · ${numDe(v['pcs']).toInt()} pallets${txt(v['linea_aerea']).isEmpty ? '' : ' · ${txt(v['linea_aerea'])}'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _elegirVuelo,
                  ),
                ),
              ], minimo: 640),
              const SizedBox(height: 12),
              Text('Consignatario', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Paleta.tintaSuave)),
              const SizedBox(height: 6),
              if (_cliente == null)
                Text('Elegí un cliente para cargar sus consignatarios.',
                    style: TextStyle(fontSize: 12.5, color: Paleta.tintaTenue))
              else if (opcionesCons.isEmpty)
                Text('Sin consignatarios asociados.', style: TextStyle(fontSize: 12.5, color: Paleta.tintaTenue))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final o in opcionesCons)
                      ChoiceChip(
                        label: Text(o.etiqueta),
                        selected: _consignatario == o.consignatario,
                        showCheckmark: false,
                        selectedColor: Paleta.verde,
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _consignatario == o.consignatario ? Colors.white : Paleta.tinta,
                        ),
                        backgroundColor: Paleta.superficie,
                        side: BorderSide(color: _consignatario == o.consignatario ? Paleta.verdeOscuro : Paleta.borde),
                        shape: const StadiumBorder(),
                        onSelected: (_) => setState(() => _elegirConsignatario(o)),
                      ),
                  ],
                ),
              const SizedBox(height: 14),
              _tablaCalibres(),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  Text(
                    _ayuda ?? 'Completá el bloque y añadilo; podés cargar hasta $maxBloquesPrograma.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _ayuda == null ? Paleta.tintaTenue : Paleta.oro,
                      fontWeight: _ayuda == null ? FontWeight.w400 : FontWeight.w700,
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Paleta.verdeOscuro),
                    onPressed: _agregarBloque,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('Añadir a $_camion (${_bloques.length}/$maxBloquesPrograma)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _selectorCamiones() {
    final conteo = <String, (int, int)>{};
    for (final b in _bloques) {
      final (p, n) = conteo[b.camion] ?? (0, 0);
      conteo[b.camion] = (p + b.total, n + 1);
    }
    Widget opcion(String nombre) {
      final sel = nombre == _camion;
      final info = conteo[nombre];
      final meta = info == null ? 'Vacío' : '${info.$1} pallets · ${info.$2} bloque${info.$2 == 1 ? '' : 's'}';
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _camion = nombre),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? Paleta.suave(Paleta.verde, 0.10) : Paleta.superficie,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? Paleta.verde : Paleta.borde, width: sel ? 1.4 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping_rounded, size: 20, color: sel ? Paleta.verde : Paleta.tintaSuave),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(nombre, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Paleta.tinta)),
                  Text(meta, style: TextStyle(fontSize: 11, color: Paleta.tintaSuave)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final n in _camiones) opcion(n),
        OutlinedButton.icon(
          onPressed: _camiones.length >= maxCamiones
              ? null
              : () => setState(() {
                  final nuevo = siguienteCamion(_camiones);
                  _camiones.add(nuevo);
                  _camion = nuevo;
                }),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Otro camión'),
        ),
      ],
    );
  }

  Widget _tablaCalibres() {
    Widget encabezado(String t, {double? ancho}) => SizedBox(width: ancho, child: textoEncabezado(t));
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Paleta.borde),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Paleta.superficieSuave,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                encabezado('Calibre', ancho: 70),
                encabezado('Cantidad', ancho: 92),
                const SizedBox(width: 8),
                encabezado('Tamaño', ancho: 92),
                const SizedBox(width: 8),
                Expanded(child: textoEncabezado('N° de pallets — uno por uno o rango (200-205) + Enter')),
              ],
            ),
          ),
          for (final c in calibresPrograma) _filaCalibre(c),
        ],
      ),
    );
  }

  Widget _filaCalibre(String c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Paleta.bordeSuave))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Pastilla(texto: c, color: Paleta.verde),
            ),
          ),
          SizedBox(
            width: 92,
            child: campoTexto(_cant[c]!, '', pista: '0', tipo: TipoCampo.entero, alCambiar: (_) => setState(() {})),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 92, child: campoTexto(_tam[c]!, '', mayusculas: true)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 42),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Paleta.superficie,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Paleta.borde),
              ),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final p in _pallets[c]!)
                    InputChip(
                      label: Text(p, style: TextStyle(fontSize: 11.5, color: Paleta.azul, fontWeight: FontWeight.w700)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Paleta.suave(Paleta.azul, 0.08),
                      side: BorderSide(color: Paleta.azul.withValues(alpha: 0.3)),
                      onDeleted: () => _quitarPallet(c, p),
                    ),
                  SizedBox(
                    width: 170,
                    child: Focus(
                      onFocusChange: (tiene) {
                        if (!tiene) _agregarPallets(c); // al salir del campo también se agrega
                      },
                      child: TextField(
                        controller: _palletIn[c],
                        onSubmitted: (_) => _agregarPallets(c),
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: c == calibresPrograma.first ? 'Ej: 101, 102 o 200-205' : 'Pallet o rango + Enter',
                          hintStyle: TextStyle(fontSize: 12, color: Paleta.tintaTenue),
                        ),
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

  // ── Columna derecha: vuelo, cupo y bloques ──

  Widget _columnaLateral(int total) {
    final (capacidad, usados, libres) = _cupo;
    final alerta = libres < 0;
    final colorCupo = alerta ? Paleta.peligro : Paleta.verde;
    Widget dato(String rotulo, String valor, {bool destacado = false}) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: destacado ? Paleta.suave(colorCupo, 0.10) : Paleta.superficieSuave,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo, style: TextStyle(fontSize: 10.5, color: Paleta.tintaSuave, fontWeight: FontWeight.w600)),
            Text(valor,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: destacado ? colorCupo : Paleta.tinta,
                  fontFeatures: cifrasTabulares,
                )),
          ],
        ),
      ),
    );
    Widget info(String rotulo, String valor) => Expanded(
      child: InputDecorator(
        decoration: decoCampo(rotulo, soloLectura: true),
        child: Text(valor.isEmpty ? '—' : valor, style: TextStyle(fontSize: 13, color: Paleta.tinta)),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: alerta ? Border.all(color: Paleta.peligro) : null),
          child: SeccionForm(
            titulo: 'Vuelo seleccionado',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [info('Destino', _destino), const SizedBox(width: 8), info('ETD 1', _horaVuelo)]),
                const SizedBox(height: 10),
                Row(children: [
                  dato('Capacidad', fmtNum(capacidad)),
                  const SizedBox(width: 6),
                  dato('Usados', fmtNum(usados)),
                  const SizedBox(width: 6),
                  dato('Libres', fmtNum(libres), destacado: true),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: capacidad > 0 ? (usados / capacidad).clamp(0, 1).toDouble() : 0,
                    minHeight: 6,
                    color: colorCupo,
                    backgroundColor: Paleta.superficieHundida,
                  ),
                ),
                if (_bloques.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _aplicarVueloATodos,
                    child: const Text('Aplicar este vuelo a todos los bloques'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SeccionForm(
          titulo: 'Bloques del programa · clic para editar',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_bloques.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('Todavía no agregaste bloques.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Paleta.tintaTenue)),
                )
              else
                for (final (i, b) in _bloques.indexed) _tarjetaBloque(i, b),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text('Total programa', style: TextStyle(fontWeight: FontWeight.w700, color: Paleta.tintaSuave)),
                  ),
                  Text('${fmtNum(total)} pallets',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Paleta.verdeTitulo)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjetaBloque(int i, Bloque b) {
    final ok = _vueloEnFecha(b.vuelo);
    final color = ok ? Paleta.borde : Paleta.oro;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: ok ? Paleta.superficie : Paleta.suave(Paleta.oro, 0.08),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => _editarBloque(b),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: color)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('#${i + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: Paleta.tintaSuave)),
                          Pastilla(texto: b.camion, color: Paleta.verde, icono: Icons.local_shipping_rounded),
                          Text(b.cliente, style: TextStyle(fontWeight: FontWeight.w800, color: Paleta.tinta)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${b.marca} · ${b.destino} · ${b.vuelo}',
                          style: TextStyle(fontSize: 11.5, color: Paleta.tintaSuave)),
                      Text(b.resumenCalibres, style: TextStyle(fontSize: 11.5, color: Paleta.tintaSuave)),
                      if (!ok)
                        Text('Vuelo de otra fecha: cambialo',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Paleta.oro)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text('${b.total}',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Paleta.verdeTitulo)),
                    Text('pl', style: TextStyle(fontSize: 10.5, color: Paleta.tintaSuave)),
                  ],
                ),
                IconButton(
                  tooltip: 'Quitar bloque',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 18, color: Paleta.peligro),
                  onPressed: () => setState(() => _bloques.remove(b)),
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
