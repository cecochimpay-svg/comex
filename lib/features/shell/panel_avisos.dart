import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/avisos/avisos_admin.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/comunes.dart';
import '../../widgets/listados.dart';
import '../vuelos/vuelos_datos.dart';

/// Avisos flotantes para el ADM (arriba a la derecha): una tarjeta por usuario con lo que cambió en sus
/// despachos. No se van solos: quedan hasta que el ADM toca la X.
class PanelAvisos extends StatelessWidget {
  const PanelAvisos({super.key, this.maximoTarjetas = 3});

  final int maximoTarjetas;

  @override
  Widget build(BuildContext context) {
    final AvisosAdmin avisos;
    try {
      avisos = context.watch<AvisosAdmin>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final grupos = avisos.grupos;
    final pantalla = MediaQuery.sizeOf(context);
    final ancho = min(400.0, pantalla.width - 24);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topRight,
      child: grupos.isEmpty
          ? const SizedBox.shrink()
          : ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ancho, maxHeight: max(160, pantalla.height - 150)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final g in grupos.take(maximoTarjetas))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TarjetaAvisos(
                          key: ValueKey('avisos-${g.usuario}'),
                          grupo: g,
                          ancho: ancho,
                          alCerrar: () => avisos.cerrarGrupo(g.usuario),
                        ),
                      ),
                    if (grupos.length > 1)
                      Material(
                        color: Paleta.superficie,
                        elevation: 6,
                        shadowColor: const Color(0x55101814),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (grupos.length > maximoTarjetas)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8, right: 4),
                                  child: Text(
                                    '+${grupos.length - maximoTarjetas} usuario(s) más',
                                    style: TextStyle(fontSize: 12, color: Paleta.tintaSuave),
                                  ),
                                ),
                              TextButton.icon(
                                onPressed: avisos.cerrarTodos,
                                icon: const Icon(Icons.done_all_rounded, size: 16),
                                label: Text('Cerrar todos (${avisos.total})'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class TarjetaAvisos extends StatefulWidget {
  const TarjetaAvisos({super.key, required this.grupo, required this.ancho, required this.alCerrar});

  final GrupoAvisos grupo;
  final double ancho;
  final VoidCallback alCerrar;

  @override
  State<TarjetaAvisos> createState() => _TarjetaAvisosState();
}

class _TarjetaAvisosState extends State<TarjetaAvisos> with SingleTickerProviderStateMixin {
  static const _resumidos = 3;
  bool _todos = false;
  late final _entrada = AnimationController(vsync: this, duration: const Duration(milliseconds: 320))..forward();

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.grupo;
    final tono = Paleta.oro;
    final altas = g.cuantos('ALTA');
    final ediciones = g.cuantos('EDICION');
    final bajas = g.cuantos('BAJA');
    final lista = _todos ? g.avisos : g.avisos.take(_resumidos).toList();
    final curva = CurvedAnimation(parent: _entrada, curve: Curves.easeOutCubic);

    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween(begin: const Offset(0.15, 0), end: Offset.zero).animate(curva),
        child: Semantics(
          liveRegion: true,
          label: 'Aviso: ${g.usuario} hizo ${g.avisos.length} cambio(s) en despachos',
          child: Material(
            color: Paleta.superficie,
            elevation: 12,
            shadowColor: const Color(0x66101814),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: widget.ancho,
              decoration: BoxDecoration(border: Border(left: BorderSide(color: tono, width: 4))),
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconoTono(icono: Icons.notifications_active_rounded, tono: tono, tamano: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CAMBIOS EN DESPACHOS',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: tono),
                            ),
                            Text(
                              g.usuario,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Paleta.tinta),
                            ),
                            Text(
                              '${g.avisos.length} cambio(s) · ${haceCuanto(g.ultimo)}',
                              style: TextStyle(fontSize: 11.5, color: Paleta.tintaSuave),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar aviso',
                        onPressed: widget.alCerrar,
                        icon: Icon(Icons.close_rounded, size: 20, color: Paleta.tintaSuave),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (altas > 0) Pastilla(texto: '$altas alta(s)', color: Paleta.exito, icono: Icons.add_rounded),
                      if (ediciones > 0)
                        Pastilla(texto: '$ediciones edición(es)', color: Paleta.azul, icono: Icons.edit_rounded),
                      if (bajas > 0) Pastilla(texto: '$bajas baja(s)', color: Paleta.peligro, icono: Icons.delete_outline_rounded),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final a in lista) _LineaAviso(a: a),
                  if (g.avisos.length > _resumidos)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _todos = !_todos),
                        child: Text(_todos ? 'Ver menos' : 'Ver los ${g.avisos.length} cambios'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LineaAviso extends StatelessWidget {
  const _LineaAviso({required this.a});

  final AvisoCambio a;

  @override
  Widget build(BuildContext context) {
    final (texto, color) = switch (a.accion) {
      'ALTA' => ('ALTA', Paleta.exito),
      'BAJA' => ('BAJA', Paleta.peligro),
      _ => ('EDITÓ', Paleta.azul),
    };
    final que = [
      a.awb.isEmpty ? 'Sin AWB' : 'AWB ${a.awb}',
      if (a.vuelo.isNotEmpty) a.vuelo,
      if (a.destino.isNotEmpty) a.destino,
      if (a.semana != null && a.semana! > 0) 'W${a.semana}',
    ].join(' · ');
    const maxCambios = 4;
    final cambios = a.cambios.entries.toList();

    return Container(
      margin: const EdgeInsets.only(top: 6, right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Paleta.superficieSuave, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pastilla(texto: texto, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  que,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Paleta.tinta),
                ),
              ),
              Text(horaCorta(a.fecha), style: TextStyle(fontSize: 11, color: Paleta.tintaTenue)),
            ],
          ),
          for (final c in cambios.take(maxCambios))
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 2),
              child: Text(
                '${etiquetaColumnaVuelo(c.key)}: ${valorColumnaVuelo(c.key, c.value.$1)} → ${valorColumnaVuelo(c.key, c.value.$2)}',
                style: TextStyle(fontSize: 11.5, color: Paleta.tintaSuave),
              ),
            ),
          if (cambios.length > maxCambios)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 2),
              child: Text(
                '+${cambios.length - maxCambios} dato(s) más',
                style: TextStyle(fontSize: 11, color: Paleta.tintaTenue),
              ),
            ),
        ],
      ),
    );
  }
}

String _dos(int n) => n.toString().padLeft(2, '0');

/// "recién", "hace 5 min", "hace 2 h", "ayer 14:30" o "17/11 14:30".
String haceCuanto(DateTime f, {DateTime? ahora}) {
  final ya = ahora ?? DateTime.now();
  final d = ya.difference(f);
  if (d.inMinutes < 1) return 'recién';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 12) return 'hace ${d.inHours} h';
  return horaCorta(f, ahora: ya);
}

/// Hora si es de hoy; "ayer HH:MM"; si no, "DD/MM HH:MM".
String horaCorta(DateTime f, {DateTime? ahora}) {
  final ya = ahora ?? DateTime.now();
  final hora = '${_dos(f.hour)}:${_dos(f.minute)}';
  final hoy = DateTime(ya.year, ya.month, ya.day);
  final dia = DateTime(f.year, f.month, f.day);
  if (dia == hoy) return hora;
  if (dia == hoy.subtract(const Duration(days: 1))) return 'ayer $hora';
  return '${_dos(f.day)}/${_dos(f.month)} $hora';
}
