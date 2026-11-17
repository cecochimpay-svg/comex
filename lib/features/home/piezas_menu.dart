import 'package:flutter/material.dart';

import '../../core/nav/catalogo.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/animaciones.dart';
import 'resumen_datos.dart';
import 'resumen_repo.dart';

/// Piezas comunes del inicio, del panel de cada área y de los menús de la barra.

/// Relee [ResumenVivo] al abrir la pantalla (el inicio y el panel de cada área). Lo que cambie después lo
/// relee `ResumenVivo.seguir`, enganchado a la sincronización al arrancar la app.
mixin ResumenQueSeActualiza<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ResumenVivo.actualizar();
    });
  }
}

/// "3 sin subir" en oro: registros del área que todavía no se sincronizaron.
class PildoraPendientes extends StatelessWidget {
  const PildoraPendientes({super.key, required this.cantidad, this.compacta = false});

  final int cantidad;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final oro = Paleta.oro;
    return Tooltip(
      message: '$cantidad ${cantidad == 1 ? 'registro' : 'registros'} de esta área sin subir a la nube',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compacta ? 6 : 8, vertical: 3),
        decoration: BoxDecoration(
          color: Paleta.suave(oro, 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: oro.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_upload_rounded, size: 12, color: oro),
            const SizedBox(width: 4),
            Text(
              compacta ? '$cantidad' : '$cantidad sin subir',
              style: TextStyle(color: oro, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Número grande del área con su leyenda y los datos chicos debajo.
class DatoArea extends StatelessWidget {
  const DatoArea({super.key, required this.dato, required this.secundarios, this.tamano = 26});

  final DatoVivo dato;
  final List<DatoVivo> secundarios;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          children: [
            ContadorTexto(
              dato.valor,
              maxLines: 1,
              style: TextStyle(
                fontSize: tamano,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                height: 1.1,
                color: Paleta.verdeTitulo,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                dato.leyenda,
                style: TextStyle(fontSize: 12.5, color: Paleta.tintaSuave, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (secundarios.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            secundarios.map((d) => '$d').join('  ·  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Paleta.tintaTenue, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

/// Esqueleto del [DatoArea] mientras se lee la base.
class EsqueletoDato extends StatelessWidget {
  const EsqueletoDato({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Hueso(ancho: 130, alto: 24, radio: 7), SizedBox(height: 9), Hueso(ancho: 210, alto: 10)],
  );
}

/// Acceso directo a una pantalla dentro de una tarjeta: se pinta del color del área con el mouse.
class AccesoPantalla extends StatefulWidget {
  const AccesoPantalla({super.key, required this.pantalla, required this.tono, required this.onTap});

  final Pantalla pantalla;
  final Color tono;
  final VoidCallback onTap;

  @override
  State<AccesoPantalla> createState() => _AccesoPantallaState();
}

class _AccesoPantallaState extends State<AccesoPantalla> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tono;
    final sobre = textoSobre(t);
    return Semantics(
      button: true,
      label: widget.pantalla.titulo,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: sinAnimaciones(context) ? Duration.zero : const Duration(milliseconds: 140),
            padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
            decoration: BoxDecoration(
              color: _hover ? t : Paleta.superficieSuave,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _hover ? t : Paleta.bordeSuave),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.pantalla.icono, size: 14, color: _hover ? sobre : t),
                const SizedBox(width: 6),
                Text(
                  widget.pantalla.titulo,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _hover ? sobre : Paleta.tinta),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta chica de acceso rápido: ícono, título, detalle y flecha.
class TileAcceso extends StatelessWidget {
  const TileAcceso({
    super.key,
    required this.icono,
    required this.tono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
  });

  final IconData icono;
  final Color tono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TarjetaViva(
      tono: tono,
      radio: 12,
      etiqueta: titulo,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      onTap: onTap,
      builder: (context, activa) => Row(
        children: [
          IconoVivo(icono: icono, tono: tono, activa: activa, tamano: 38),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Paleta.tinta),
                ),
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: Paleta.tintaTenue, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          FlechaViva(tono: tono, activa: activa, tamano: 24),
        ],
      ),
    );
  }
}
