import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/sesion_controller.dart';
import '../../core/sync/servicio_sync.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/avisos.dart';
import '../../widgets/dialogo_clave_nube.dart';

/// Sincroniza todo con la nube. Muestra cuántos registros quedan pendientes de subir.
class BotonSincronizar extends StatefulWidget {
  const BotonSincronizar({super.key, this.compacto = false});

  /// Sólo el ícono (pantallas angostas).
  final bool compacto;

  @override
  State<BotonSincronizar> createState() => _BotonSincronizarState();
}

class _BotonSincronizarState extends State<BotonSincronizar> with SingleTickerProviderStateMixin {
  late final AnimationController _giro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  Future<void> _sincronizar() async {
    final sync = context.read<ServicioSync>();
    final correo = context.read<SesionController>().actual?.correo ?? '';
    final r = await sync.sincronizarTodo(
      correoSesion: correo,
      pedirClave: (c, error) async => mounted ? pedirClaveNube(context, correo: c, error: error) : null,
    );
    if (!mounted) return;
    mostrarAviso(
      context,
      r.mensaje,
      tipo: switch (r.tipo) {
        TipoResultadoSync.exito => TipoAviso.exito,
        TipoResultadoSync.aviso => TipoAviso.aviso,
        TipoResultadoSync.error => TipoAviso.error,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<ServicioSync>();
    if (sync.sincronizando && !_giro.isAnimating) {
      _giro.repeat();
    } else if (!sync.sincronizando && _giro.isAnimating) {
      _giro
        ..stop()
        ..value = 0;
    }
    final pendientes = sync.pendientes;

    // Sobre la barra verde bosque: botón blanco, la acción principal de la barra.
    final boton = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: sync.sincronizando ? null : _sincronizar,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.compacto ? 9 : 13, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _giro,
                child: Icon(Icons.sync_rounded, size: 17, color: Paleta.marca),
              ),
              if (!widget.compacto) ...[
                const SizedBox(width: 8),
                Text(
                  sync.sincronizando ? 'Sincronizando…' : 'Sincronizar',
                  style: TextStyle(color: Paleta.marca, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Tooltip(
      message: pendientes > 0 ? '$pendientes registro(s) pendientes de subir' : 'Todo sincronizado',
      child: Badge(
        isLabelVisible: pendientes > 0 && !sync.sincronizando,
        label: Text(pendientes > 99 ? '99+' : '$pendientes'),
        child: boton,
      ),
    );
  }
}
