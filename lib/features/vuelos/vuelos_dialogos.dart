import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/sesion_controller.dart';
import '../../core/config.dart';
import '../../core/formato.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/formulario.dart';
import 'vuelos_datos.dart';
import 'vuelos_repo.dart';

/// Resultado de guardar: mensaje para el aviso y si quedó sólo en este equipo.
typedef GuardadoVuelo = ({String mensaje, bool pendiente});

/// Alta / edición de un despacho con las columnas de la planilla de logística.
Future<GuardadoVuelo?> dialogoVuelo(BuildContext context, {Vuelo? edicion}) =>
    showDialog<GuardadoVuelo>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoVuelo(edicion: edicion),
    );

class _DialogoVuelo extends StatefulWidget {
  const _DialogoVuelo({this.edicion});

  final Vuelo? edicion;

  @override
  State<_DialogoVuelo> createState() => _DialogoVueloState();
}

class _DialogoVueloState extends State<_DialogoVuelo> with GuardadoDialogo {
  late final _awb = TextEditingController(text: widget.edicion?.awb);
  late final _vuelo = TextEditingController(text: widget.edicion?.vuelo);
  late final _conex = TextEditingController(text: widget.edicion?.conex);
  late final _destino = TextEditingController(text: widget.edicion?.destino);
  late final _ruta = TextEditingController(text: widget.edicion?.ruta);
  late final _proforma = TextEditingController(text: widget.edicion?.proforma);
  late final _cnne = TextEditingController(text: widget.edicion?.cnne);
  late final _tarimas = TextEditingController(
    text: widget.edicion == null ? '' : numEntrada(widget.edicion!.tarimas),
  );
  late final _peso = TextEditingController(text: widget.edicion == null ? '' : numEntrada(widget.edicion!.peso));
  late final _tarifa = TextEditingController(
    text: (widget.edicion?.tarifa ?? '').replaceFirst(RegExp(r'^USD\s*', caseSensitive: false), ''),
  );

  late String _ingreso = widget.edicion?.ingreso ?? '';
  late String _etdFecha = widget.edicion?.etdFecha ?? '';
  late String _etdHora = widget.edicion?.etdHora ?? '';
  late String _etaFecha = widget.edicion?.etaFecha ?? '';
  late String _etaHora = widget.edicion?.etaHora ?? '';

  /// Un despacho nuevo arranca PROGRAMADO.
  late String _status = widget.edicion?.status ?? 'PROGRAMADO';

  @override
  void dispose() {
    for (final c in [_awb, _vuelo, _conex, _destino, _ruta, _proforma, _cnne, _tarimas, _peso, _tarifa]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _semana {
    if (_etdFecha.isEmpty && _ingreso.isEmpty && widget.edicion != null) return widget.edicion!.semana;
    return semanaDeDespacho(etd: _etdFecha, ingreso: _ingreso);
  }

  Future<void> _guardar() async {
    if (_destino.text.trim().isEmpty) return fallar('Falta el destino.');
    if (_tarimas.text.trim().isEmpty) return fallar('Faltan las tarimas.');
    if (_peso.text.trim().isEmpty) return fallar('Falta el peso.');
    if (_etdFecha.isNotEmpty && _etaFecha.isNotEmpty && _etaFecha.compareTo(_etdFecha) < 0) {
      return fallar('La ETA no puede ser anterior a la ETD.');
    }
    final sesion = context.read<SesionController>().actual!;
    final datos = DatosFormularioVuelo(
      awb: _awb.text,
      ingreso: _ingreso,
      destino: _destino.text,
      ruta: _ruta.text,
      vuelo: _vuelo.text,
      proforma: _proforma.text,
      etdFecha: _etdFecha,
      etdHora: _etdHora,
      conex: _conex.text,
      etaFecha: _etaFecha,
      etaHora: _etaHora,
      tarimas: (leerNum(_tarimas.text) ?? 0).round(),
      peso: (leerNum(_peso.text) ?? 0).round(),
      tarifa: _tarifa.text,
      status: _status,
      cnne: _cnne.text,
    );
    await ejecutar(() async {
      final r = await RepoVuelos.guardar(sesion, datos, previo: widget.edicion);
      final que = widget.edicion == null ? 'Despacho registrado' : 'Despacho actualizado';
      final falta = r.omitidas.isEmpty
          ? ''
          : ' (sin ${r.omitidas.join(', ')}: falta correr la migración 006 en Supabase)';
      return (
        mensaje: r.enNube ? '$que en la semana $_semana$falta.' : '$que sin conexión: se sube al sincronizar.',
        pendiente: !r.enNube,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.edicion;
    final tono = Paleta.azul;
    return MarcoDialogo(
      titulo: e == null ? 'Registrar despacho' : 'Editar despacho',
      subtitulo: 'Week $_semana / ${Config.temporada}${e == null ? '' : ' · registro ${e.registro}'}',
      icono: Icons.flight_takeoff_rounded,
      tono: tono,
      anchoMaximo: 860,
      error: error,
      acciones: [botonCancelar(), botonGuardar('Guardar despacho', _guardar)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SeccionForm(
            titulo: 'Guía y vuelo',
            child: Column(
              children: [
                FilaCampos([
                  (3, campoTexto(_awb, 'AWB', pista: '020-03123046', autofoco: e == null, acento: tono)),
                  (2, campoTexto(_vuelo, 'Vuelo', pista: 'LH 511', mayusculas: true, acento: tono)),
                  (2, campoTexto(_conex, 'Conex', pista: 'Vacío si es directo', mayusculas: true, acento: tono)),
                ]),
                const SizedBox(height: 12),
                FilaCampos([
                  (2, campoTexto(_destino, 'Destino *', pista: 'PVG', mayusculas: true, acento: tono)),
                  (3, campoTexto(_ruta, 'Ruta', pista: 'EZE-FRA-PVG', mayusculas: true, acento: tono)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SeccionForm(
            titulo: 'Fechas',
            child: Column(
              children: [
                FilaCampos([
                  (1, CampoFechaVuelo(etiqueta: 'Ingreso TCA requerido', fecha: _ingreso, alCambiar: (f) => setState(() => _ingreso = f))),
                  (1, _SemanaCalculada(semana: _semana)),
                ]),
                const SizedBox(height: 12),
                FilaCampos([
                  (3, CampoFechaVuelo(etiqueta: 'ETD · fecha', fecha: _etdFecha, alCambiar: (f) => setState(() => _etdFecha = f))),
                  (2, CampoHoraVuelo(etiqueta: 'ETD · hora', hora: _etdHora, alCambiar: (h) => setState(() => _etdHora = h))),
                  (3, CampoFechaVuelo(etiqueta: 'ETA · fecha', fecha: _etaFecha, alCambiar: (f) => setState(() => _etaFecha = f))),
                  (2, CampoHoraVuelo(etiqueta: 'ETA · hora', hora: _etaHora, alCambiar: (h) => setState(() => _etaHora = h))),
                ], minimo: 640),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SeccionForm(
            titulo: 'Carga',
            child: Column(
              children: [
                FilaCampos([
                  (1, campoTexto(_proforma, 'Proforma', pista: 'PF-1234', acento: tono)),
                  (1, campoTexto(_cnne, 'CNNE', pista: 'Consignatario', acento: tono)),
                ]),
                const SizedBox(height: 12),
                FilaCampos([
                  (1, campoTexto(_tarimas, 'Tarimas *', tipo: TipoCampo.entero, acento: tono)),
                  (1, campoTexto(_peso, 'Peso (kg) *', tipo: TipoCampo.entero, acento: tono)),
                  (1, campoTexto(_tarifa, 'Tarifa (USD)', pista: '3,10', acento: tono)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SeccionForm(
            titulo: 'Status',
            child: SelectorStatusLed(valor: _status, alCambiar: (s) => setState(() => _status = s)),
          ),
        ],
      ),
    );
  }
}

/// Botones LED del status: se enciende el elegido; tocarlo de nuevo lo apaga (sin status).
class SelectorStatusLed extends StatelessWidget {
  const SelectorStatusLed({super.key, required this.valor, required this.alCambiar});

  final String valor;
  final ValueChanged<String> alCambiar;

  @override
  Widget build(BuildContext context) {
    final actual = valor.trim().toUpperCase();
    final nombres = [
      for (final e in estadosDespacho) e.nombre,
      // Status escrito a mano en un registro viejo: aparece como uno más para no perderlo.
      if (actual.isNotEmpty && !estadosDespacho.any((e) => e.nombre == actual)) actual,
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth < 420 ? 2 : 3;
        final ancho = (c.maxWidth - (columnas - 1) * 8) / columnas;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in nombres)
              SizedBox(
                width: ancho,
                child: BotonLed(
                  texto: n,
                  color: colorStatus(n),
                  encendido: n == actual,
                  onTap: () => alCambiar(n == actual ? '' : n),
                ),
              ),
          ],
        );
      },
    );
  }
}

class BotonLed extends StatefulWidget {
  const BotonLed({super.key, required this.texto, required this.color, required this.encendido, required this.onTap});

  final String texto;
  final Color color;
  final bool encendido;
  final VoidCallback onTap;

  @override
  State<BotonLed> createState() => _BotonLedState();
}

class _BotonLedState extends State<BotonLed> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final on = widget.encendido;
    return Semantics(
      button: true,
      selected: on,
      label: 'Status ${widget.texto}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: on ? Paleta.suave(c, 0.12) : Paleta.superficie,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: on || _hover ? c : Paleta.borde, width: on ? 1.4 : 1),
            ),
            child: Row(
              children: [
                Led(color: c, encendido: on),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    widget.texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: on || _hover ? Paleta.tinta : Paleta.tintaSuave,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// LED redondo: encendido brilla con su color; apagado queda gris hundido.
class Led extends StatelessWidget {
  const Led({super.key, required this.color, this.encendido = true, this.tamano = 9});

  final Color color;
  final bool encendido;
  final double tamano;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: tamano,
    height: tamano,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: encendido ? color : Paleta.bordeFuerte,
      boxShadow: encendido
          ? [
              BoxShadow(color: color.withValues(alpha: 0.30), spreadRadius: 3),
              BoxShadow(color: color.withValues(alpha: 0.65), blurRadius: 10),
            ]
          : null,
    ),
  );
}

class _SemanaCalculada extends StatelessWidget {
  const _SemanaCalculada({required this.semana});

  final int semana;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: decoCampo('Semana', soloLectura: true),
    child: Text(
      'Week $semana / ${Config.temporada}',
      style: TextStyle(fontWeight: FontWeight.w700, color: Paleta.verdeTitulo),
    ),
  );
}

/// Fecha opcional con calendario y botón para borrarla.
class CampoFechaVuelo extends StatelessWidget {
  const CampoFechaVuelo({super.key, required this.etiqueta, required this.fecha, required this.alCambiar});

  final String etiqueta;
  final String fecha;
  final ValueChanged<String> alCambiar;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () async {
      final f = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(fecha) ?? DateTime.now(),
        firstDate: DateTime(Config.temporada - 1),
        lastDate: DateTime(Config.temporada + 2),
      );
      if (f != null) alCambiar(fechaIso(f));
    },
    child: InputDecorator(
      decoration: decoCampo(etiqueta).copyWith(
        suffixIcon: fecha.isEmpty
            ? const Icon(Icons.calendar_today_rounded, size: 16)
            : IconButton(
                tooltip: 'Borrar fecha',
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () => alCambiar(''),
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 20),
      ),
      child: Text(fecha.isEmpty ? '—' : fechaCorta(fecha), maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}

/// Hora opcional (HH:MM) con reloj y botón para borrarla.
class CampoHoraVuelo extends StatelessWidget {
  const CampoHoraVuelo({super.key, required this.etiqueta, required this.hora, required this.alCambiar});

  final String etiqueta;
  final String hora;
  final ValueChanged<String> alCambiar;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () async {
      final partes = hora.split(':');
      final inicial = partes.length >= 2
          ? TimeOfDay(hour: int.tryParse(partes[0]) ?? 0, minute: int.tryParse(partes[1]) ?? 0)
          : TimeOfDay.now();
      final h = await showTimePicker(
        context: context,
        initialTime: inicial,
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
      );
      if (h != null) alCambiar('${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}');
    },
    child: InputDecorator(
      decoration: decoCampo(etiqueta).copyWith(
        suffixIcon: hora.isEmpty
            ? const Icon(Icons.schedule_rounded, size: 16)
            : IconButton(
                tooltip: 'Borrar hora',
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () => alCambiar(''),
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 20),
      ),
      child: Text(hora.isEmpty ? '—' : hora, maxLines: 1),
    ),
  );
}
