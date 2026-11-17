import 'dart:math';

import 'package:flutter/material.dart';

import '../core/tema/paleta.dart';

/// Logo circular de la empresa (el mismo del ícono de la app); si falta la imagen, muestra la inicial.
class LogoComex extends StatelessWidget {
  const LogoComex({super.key, this.tamano = 40});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Image.asset(
        'assets/icono/icono.png',
        fit: BoxFit.contain,
        cacheWidth: (tamano * 3).round(),
        errorBuilder: (context, error, stack) => Center(
          child: Text(
            'S',
            style: TextStyle(color: Paleta.verde, fontWeight: FontWeight.w900, fontSize: tamano * 0.45),
          ),
        ),
      ),
    );
  }
}

/// "Powered by AgroSoft J&L" con su logo (pie del login y menú del usuario, igual que el original).
class FirmaAgrosoft extends StatelessWidget {
  const FirmaAgrosoft({super.key, this.centrada = false});

  final bool centrada;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: centrada ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: centrada ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            'POWERED BY',
            overflow: TextOverflow.ellipsis,
            style: t.labelSmall?.copyWith(color: Paleta.tintaTenue, letterSpacing: 0.8, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.asset(
            'assets/logo_agrosoft.png',
            width: 20,
            height: 20,
            cacheWidth: 60,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'AgroSoft J&L',
            overflow: TextOverflow.ellipsis,
            style: t.labelMedium?.copyWith(color: Paleta.verde, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

/// Baldosa con el ícono de un área, en su color.
class IconoTono extends StatelessWidget {
  const IconoTono({super.key, required this.icono, required this.tono, this.tamano = 46, this.solido = false});

  final IconData icono;
  final Color tono;
  final double tamano;
  final bool solido;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tamano * 0.26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: solido
              ? [Color.lerp(tono, Colors.white, 0.12)!, tono]
              : [Paleta.suave(tono, 0.15), Paleta.suave(tono, 0.07)],
        ),
        border: solido ? null : Border.all(color: tono.withValues(alpha: 0.14)),
      ),
      child: Icon(icono, size: tamano * 0.48, color: solido ? Colors.white : tono),
    );
  }
}

/// Superficie interactiva con elevación al pasar el mouse, foco de teclado y "hundimiento" al tocar.
class Presionable extends StatefulWidget {
  const Presionable({super.key, required this.builder, this.onTap, this.etiqueta});

  final Widget Function(BuildContext context, bool resaltado) builder;
  final VoidCallback? onTap;
  final String? etiqueta;

  @override
  State<Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<Presionable> {
  bool _hover = false;
  bool _foco = false;
  bool _presionado = false;

  void _presionar(bool v) {
    if (widget.onTap != null && _presionado != v) setState(() => _presionado = v);
  }

  @override
  Widget build(BuildContext context) {
    final resaltado = _hover || _foco;
    return Semantics(
      button: widget.onTap != null,
      label: widget.etiqueta,
      child: FocusableActionDetector(
        enabled: widget.onTap != null,
        mouseCursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _foco = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _presionar(true),
          onTapUp: (_) => _presionar(false),
          onTapCancel: () => _presionar(false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _presionado ? 0.985 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, resaltado ? -2 : 0, 0),
              child: widget.builder(context, resaltado),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grilla que acomoda la cantidad de columnas al ancho disponible.
class GrillaAdaptable extends StatelessWidget {
  const GrillaAdaptable({
    super.key,
    required this.children,
    this.anchoMinimo = 280,
    this.maxColumnas = 3,
    this.espacio = 12,
  });

  final List<Widget> children;
  final double anchoMinimo;
  final int maxColumnas;
  final double espacio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columnas = max(1, min(maxColumnas, ((c.maxWidth + espacio) / (anchoMinimo + espacio)).floor()));
      final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
      return Wrap(
        spacing: espacio,
        runSpacing: espacio,
        children: [for (final h in children) SizedBox(width: ancho, child: h)],
      );
    });
  }
}

/// Contenedor estándar de página: ancho máximo, márgenes según pantalla y scroll.
class PaginaContenido extends StatelessWidget {
  const PaginaContenido({super.key, required this.child, this.anchoMaximo = 1240});

  final Widget child;
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final lateral = ancho < 600 ? 12.0 : 24.0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(lateral, ancho < 600 ? 12 : 18, lateral, 36),
      child: Center(
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: anchoMaximo), child: child),
      ),
    );
  }
}

/// Rótulo de sección en mayúsculas.
class Rotulo extends StatelessWidget {
  const Rotulo(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Paleta.tintaSuave,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
    );
  }
}

/// Punto verde que "late": indica el motor local activo.
class LedPulso extends StatefulWidget {
  const LedPulso({super.key, this._color});

  final Color? _color;
  Color get color => _color ?? Paleta.exito;

  @override
  State<LedPulso> createState() => _LedPulsoState();
}

class _LedPulsoState extends State<LedPulso> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.7), blurRadius: 7)],
        ),
      ),
    );
  }
}

/// Reparte [n] elementos en filas parejas sin huecos para hasta [columnas] por fila:
/// 5 en 3 columnas -> [2, 3] (o [3, 2] con [cortasPrimero] en false); 4 en 3 -> [2, 2].
List<int> repartirFilas(int n, int columnas, {bool cortasPrimero = true}) {
  if (n <= 0) return const [];
  final c = max(1, columnas);
  final filas = (n + c - 1) ~/ c;
  final base = n ~/ filas;
  final extra = n % filas;
  return [
    for (var i = 0; i < filas; i++)
      base + ((cortasPrimero ? i >= filas - extra : i < extra) ? 1 : 0),
  ];
}

/// Grilla sin huecos: cada fila se llena a lo ancho (las filas cortas tienen tarjetas más anchas) y todas
/// las tarjetas de una fila tienen el mismo alto. Las columnas salen del ancho disponible.
class GrillaLlena extends StatelessWidget {
  const GrillaLlena({
    super.key,
    required this.children,
    this.anchoMinimo = 280,
    this.maxColumnas = 3,
    this.espacio = 14,
    this.cortasPrimero = true,
  });

  final List<Widget> children;
  final double anchoMinimo;
  final int maxColumnas;
  final double espacio;

  /// Las filas con menos tarjetas (más anchas) van arriba: sirve para destacar las primeras.
  final bool cortasPrimero;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = max(1, min(maxColumnas, ((c.maxWidth + espacio) / (anchoMinimo + espacio)).floor()));
        final filas = repartirFilas(children.length, columnas, cortasPrimero: cortasPrimero);
        var i = 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (f, cuantos) in filas.indexed) ...[
              if (f > 0) SizedBox(height: espacio),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < cuantos; j++) ...[
                      if (j > 0) SizedBox(width: espacio),
                      Expanded(child: children[i++]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
