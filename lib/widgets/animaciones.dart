import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/tema/paleta.dart';

/// Piezas con movimiento para los menús (como las del panel de oficina de cosecha_agrosoft).
/// Todo con lo que trae Flutter; si el sistema tiene las animaciones apagadas, no se mueve nada.
/// Ninguna se repite para siempre: los tests pueden usar `pumpAndSettle`.

bool sinAnimaciones(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Entrada escalonada: aparece con un fundido y sube unos píxeles. [orden] = posición en la grilla.
/// La espera va dentro de la misma animación (sin timers sueltos).
class Aparecer extends StatefulWidget {
  const Aparecer({super.key, required this.orden, required this.child});

  final int orden;
  final Widget child;

  @override
  State<Aparecer> createState() => _AparecerState();
}

class _AparecerState extends State<Aparecer> with SingleTickerProviderStateMixin {
  static const _paso = 45;
  static const _dura = 420;

  late final AnimationController _ctrl;
  late final Animation<double> _curva;
  late final Animation<Offset> _desde;

  @override
  void initState() {
    super.initState();
    // Máximo 10 pasos de espera: con muchas tarjetas, las últimas no tardan una eternidad.
    final espera = _paso * math.min(widget.orden, 10).toInt();
    final total = espera + _dura;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _curva = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(espera / total, 1, curve: Curves.easeOutCubic),
    );
    _desde = Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(_curva);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (sinAnimaciones(context)) {
      _ctrl.value = 1;
    } else if (_ctrl.isDismissed) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (sinAnimaciones(context)) return widget.child;
    return FadeTransition(
      opacity: _curva,
      child: SlideTransition(position: _desde, child: widget.child),
    );
  }
}

/// Tarjeta de menú con vida: brillo del color del área desde la esquina, marca de agua del ícono, se eleva
/// con el mouse, se hunde al tocarla y se usa con el teclado (Tab + Enter, con anillo de foco).
/// [builder] recibe `activa` (mouse encima o con foco) para animar lo de adentro.
class TarjetaViva extends StatefulWidget {
  const TarjetaViva({
    super.key,
    required this.tono,
    required this.builder,
    this.marcaAgua,
    this.tamanoMarca = 120,
    this.onTap,
    this.radio = 12,
    this.padding = const EdgeInsets.all(16),
    this.etiqueta,
    this.alto,
  });

  /// Color del área.
  final Color tono;
  final IconData? marcaAgua;
  final double tamanoMarca;
  final VoidCallback? onTap;
  final double radio;
  final EdgeInsetsGeometry padding;
  final String? etiqueta;
  final double? alto;
  final Widget Function(BuildContext context, bool activa) builder;

  @override
  State<TarjetaViva> createState() => _TarjetaVivaState();
}

class _TarjetaVivaState extends State<TarjetaViva> {
  bool _hover = false, _foco = false, _apretada = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final activa = _hover || _foco;
    final quieta = sinAnimaciones(context);
    final dur = quieta ? Duration.zero : const Duration(milliseconds: 220);
    const curva = Curves.easeOutCubic;
    final papel = Paleta.superficie;

    final tarjeta = AnimatedContainer(
      duration: dur,
      curve: curva,
      height: w.alto,
      transform: Matrix4.translationValues(0, activa ? -3 : 0, 0),
      decoration: BoxDecoration(
        // Brillo del color del área desde la esquina de arriba a la derecha: se abre al pasar el mouse.
        gradient: RadialGradient(
          center: const Alignment(1.05, -1.15),
          radius: activa ? 1.7 : 1.1,
          colors: [Color.alphaBlend(Paleta.suave(w.tono, activa ? 0.13 : 0.075), papel), papel],
        ),
        borderRadius: BorderRadius.circular(w.radio),
        border: Border.all(
          color: _foco ? w.tono : (activa ? w.tono.withValues(alpha: 0.5) : Paleta.borde),
          width: _foco ? 1.8 : 1,
        ),
        boxShadow: activa
            ? [
                BoxShadow(
                  color: Paleta.oscuro ? const Color(0x73000000) : w.tono.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(color: w.tono.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2)),
              ]
            : Sombras.suave,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (w.marcaAgua != null)
            Positioned(
              right: -w.tamanoMarca * 0.16,
              bottom: -w.tamanoMarca * 0.2,
              child: AnimatedSlide(
                duration: dur,
                curve: curva,
                offset: activa ? const Offset(-0.06, -0.06) : Offset.zero,
                child: AnimatedRotation(
                  duration: dur,
                  curve: curva,
                  turns: activa ? -0.025 : 0,
                  child: Icon(
                    w.marcaAgua,
                    size: w.tamanoMarca,
                    color: w.tono.withValues(alpha: activa ? 0.12 : (Paleta.oscuro ? 0.07 : 0.06)),
                  ),
                ),
              ),
            ),
          Padding(padding: w.padding, child: w.builder(context, activa)),
        ],
      ),
    );

    return Semantics(
      button: w.onTap != null,
      label: w.etiqueta,
      child: FocusableActionDetector(
        enabled: w.onTap != null,
        mouseCursor: w.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (v) => setState(() {
          _hover = v;
          if (!v) _apretada = false;
        }),
        onShowFocusHighlight: (v) => setState(() => _foco = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              w.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: w.onTap == null ? null : (_) => setState(() => _apretada = true),
          onTapCancel: () => setState(() => _apretada = false),
          onTapUp: (_) => setState(() => _apretada = false),
          onTap: w.onTap,
          child: AnimatedScale(
            duration: quieta ? Duration.zero : const Duration(milliseconds: 120),
            scale: _apretada ? 0.985 : 1,
            child: tarjeta,
          ),
        ),
      ),
    );
  }
}

/// Ícono en su recuadro del color del área: con la tarjeta activa se pinta lleno, crece y se inclina.
class IconoVivo extends StatelessWidget {
  const IconoVivo({super.key, required this.icono, required this.tono, required this.activa, this.tamano = 42});

  final IconData icono;
  final Color tono;
  final bool activa;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final dur = sinAnimaciones(context) ? Duration.zero : const Duration(milliseconds: 220);
    return AnimatedScale(
      duration: dur,
      curve: Curves.easeOutBack,
      scale: activa ? 1.07 : 1,
      child: AnimatedRotation(
        duration: dur,
        curve: Curves.easeOutBack,
        turns: activa ? -0.02 : 0,
        child: AnimatedContainer(
          duration: dur,
          width: tamano,
          height: tamano,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: activa
                  ? [Color.lerp(tono, Colors.white, 0.14)!, tono]
                  : [Paleta.suave(tono, 0.16), Paleta.suave(tono, 0.07)],
            ),
            borderRadius: BorderRadius.circular(tamano * 0.28),
            border: Border.all(color: tono.withValues(alpha: activa ? 0 : 0.16)),
            boxShadow: activa
                ? [BoxShadow(color: tono.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 5))]
                : const [],
          ),
          child: Icon(icono, color: activa ? _sobre(tono) : tono, size: tamano * 0.5),
        ),
      ),
    );
  }
}

/// Texto que va encima de un color lleno: blanco, o casi negro si el color es muy claro (tonos de noche).
Color _sobre(Color c) => c.computeLuminance() > 0.45 ? const Color(0xFF10180F) : Colors.white;

/// Color legible encima de [fondo] (blanco o tinta oscura).
Color textoSobre(Color fondo) => _sobre(fondo);

/// Flecha "entrar": un círculo que se pinta del color del área y la flecha avanza.
class FlechaViva extends StatelessWidget {
  const FlechaViva({super.key, required this.tono, required this.activa, this.tamano = 30});

  final Color tono;
  final bool activa;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final dur = sinAnimaciones(context) ? Duration.zero : const Duration(milliseconds: 200);
    return AnimatedContainer(
      duration: dur,
      curve: Curves.easeOutCubic,
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: activa ? tono : Paleta.superficie.withValues(alpha: 0.7),
        shape: BoxShape.circle,
        border: Border.all(color: activa ? tono : tono.withValues(alpha: 0.22)),
      ),
      child: AnimatedSlide(
        duration: dur,
        curve: Curves.easeOutCubic,
        offset: activa ? const Offset(0.08, 0) : Offset.zero,
        child: Icon(Icons.arrow_forward_rounded, size: tamano * 0.56, color: activa ? _sobre(tono) : tono),
      ),
    );
  }
}

/// Texto con un número adentro ("1.234 kg", "U$S 3,5", "87 ha"): el número sube hasta su valor la
/// primera vez y, si cambia, se mueve del valor anterior al nuevo. Lo que no es número queda igual.
class ContadorTexto extends StatelessWidget {
  const ContadorTexto(this.texto, {super.key, this.style, this.maxLines, this.overflow});

  final String texto;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  static final _numero = RegExp(r'\d{1,3}(?:\.\d{3})+(?:,\d+)?|\d+(?:,\d+)?');

  @override
  Widget build(BuildContext context) {
    // Cifras de ancho fijo: el texto no "tiembla" mientras cuenta.
    final estilo = (style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final m = _numero.firstMatch(texto);
    if (m == null || sinAnimaciones(context)) {
      return Text(texto, style: estilo, maxLines: maxLines, overflow: overflow);
    }
    final crudo = m.group(0)!;
    final decimales = crudo.contains(',') ? crudo.split(',').last.length : 0;
    final valor = double.parse(crudo.replaceAll('.', '').replaceAll(',', '.'));
    final antes = texto.substring(0, m.start), despues = texto.substring(m.end);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: valor),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text('$antes${formatoContador(v, decimales)}$despues', style: estilo, maxLines: maxLines, overflow: overflow),
    );
  }
}

/// Número con punto de miles y coma decimal (es-AR), para [ContadorTexto].
String formatoContador(double v, int decimales) {
  final partes = v.toStringAsFixed(decimales).split('.');
  final ent = partes[0];
  final b = StringBuffer();
  for (var i = 0; i < ent.length; i++) {
    if (i > 0 && (ent.length - i) % 3 == 0) b.write('.');
    b.write(ent[i]);
  }
  return decimales > 0 ? '$b,${partes[1]}' : b.toString();
}

/// Bloque gris del esqueleto de carga (en lugar de la ruedita).
class Hueso extends StatelessWidget {
  const Hueso({super.key, this.ancho, this.alto = 12, this.radio = 6});

  final double? ancho;
  final double alto;
  final double radio;

  @override
  Widget build(BuildContext context) => Container(
    width: ancho,
    height: alto,
    decoration: BoxDecoration(color: Paleta.superficieHundida, borderRadius: BorderRadius.circular(radio)),
  );
}

/// Fundido corto al aparecer (esqueleto de carga, listado ya cargado). Una sola vez, sin desplazamiento.
class FundidoEntrada extends StatefulWidget {
  const FundidoEntrada({super.key, required this.child});

  final Widget child;

  @override
  State<FundidoEntrada> createState() => _FundidoEntradaState();
}

class _FundidoEntradaState extends State<FundidoEntrada> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  late final _curva = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (sinAnimaciones(context)) {
      _ctrl.value = 1;
    } else if (_ctrl.isDismissed) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _curva, child: widget.child);
}
