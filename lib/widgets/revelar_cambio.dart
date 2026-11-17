import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Cambio de aspecto revelado en círculo: saca una foto de la app, aplica el cambio (que la redibuja)
/// y va abriendo un agujero en la foto desde un punto (el botón que se tocó) hasta cubrir la pantalla.
/// Se monta una sola vez en el `builder` de MaterialApp con [RevelarCambio.envolver].
class RevelarCambio extends StatefulWidget {
  const RevelarCambio({super.key, required this.child});

  final Widget child;

  static final _llave = GlobalKey<_RevelarCambioState>();

  /// Envoltorio para el `builder` de MaterialApp.
  static Widget envolver(Widget child) => RevelarCambio(key: _llave, child: child);

  /// Ejecuta [cambio] (que redibuja la app) y lo revela desde [desde] (coordenadas de pantalla).
  /// Sin el envoltorio montado (o con las animaciones apagadas) aplica el cambio de una.
  static void ejecutar(VoidCallback cambio, {Offset? desde}) {
    final estado = _llave.currentState;
    if (estado == null) return cambio();
    estado._ejecutar(cambio, desde);
  }

  @override
  State<RevelarCambio> createState() => _RevelarCambioState();
}

class _RevelarCambioState extends State<RevelarCambio> with SingleTickerProviderStateMixin {
  final _marco = GlobalKey();
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
  ui.Image? _foto;
  Offset _centro = Offset.zero;

  void _ejecutar(VoidCallback cambio, Offset? desde) {
    final caja = _marco.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final sinAnimaciones = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (caja == null || sinAnimaciones || !caja.hasSize) return cambio();
    final ui.Image foto;
    try {
      foto = caja.toImageSync(pixelRatio: MediaQuery.devicePixelRatioOf(context));
    } catch (_) {
      return cambio();
    }
    _foto?.dispose();
    setState(() {
      _foto = foto;
      _centro = desde ?? caja.size.topRight(Offset.zero);
    });
    cambio();
    _ctrl.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() => _foto = null);
      foto.dispose();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _foto?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foto = _foto;
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [
        RepaintBoundary(key: _marco, child: widget.child),
        if (foto != null)
          Positioned.fill(
            child: AbsorbPointer(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, _) => ClipPath(
                  clipper: _Agujero(_centro, Curves.easeInOutCubic.transform(_ctrl.value)),
                  child: RawImage(image: foto, fit: BoxFit.fill),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Toda la foto menos un círculo que crece desde [centro] hasta la esquina más lejana.
class _Agujero extends CustomClipper<Path> {
  const _Agujero(this.centro, this.avance);

  final Offset centro;
  final double avance;

  @override
  Path getClip(Size size) {
    final lejos = [
      Offset.zero,
      size.topRight(Offset.zero),
      size.bottomLeft(Offset.zero),
      size.bottomRight(Offset.zero),
    ].map((e) => (e - centro).distance).reduce(math.max);
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: centro, radius: lejos * avance));
  }

  @override
  bool shouldReclip(_Agujero old) => old.avance != avance || old.centro != centro;
}
