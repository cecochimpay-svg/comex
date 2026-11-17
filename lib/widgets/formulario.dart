import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formato.dart';
import '../core/tema/paleta.dart';

/// Piezas de formulario compartidas por los diálogos de alta / edición de todos los módulos.

/// Marco de diálogo (estilo `DialogoOficina`): cabecera en degradé con ícono y título en blanco
/// (roja en bajas), cuerpo con scroll sobre un fondo apenas verde, error en línea y pie con la botonera.
class MarcoDialogo extends StatelessWidget {
  const MarcoDialogo({
    super.key,
    required this.titulo,
    required this.icono,
    required this.tono,
    required this.child,
    required this.acciones,
    this.anchoMaximo = 720,
    this.error,
    this.subtitulo,
  });

  final String titulo;
  final IconData icono;
  final Color tono;
  final Widget child;
  final List<Widget> acciones;
  final double anchoMaximo;
  final String? error;

  /// Línea chica debajo del título (opcional).
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    final angosta = MediaQuery.sizeOf(context).width < 600;
    final lado = angosta ? 14.0 : 18.0;
    final fondoCuerpo = Paleta.dual(0xFFF5F8F6, 0xFF0F1512);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: angosta ? 10 : 32, vertical: 24),
      clipBehavior: Clip.antiAlias,
      elevation: 24,
      shadowColor: const Color(0x80101814),
      backgroundColor: Paleta.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: anchoMaximo),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CabeceraDialogo(titulo: titulo, icono: icono, tono: tono, subtitulo: subtitulo),
            Flexible(
              child: ColoredBox(
                color: fondoCuerpo,
                child: SingleChildScrollView(padding: EdgeInsets.all(lado), child: child),
              ),
            ),
            if (error != null)
              Container(
                color: fondoCuerpo,
                padding: EdgeInsets.fromLTRB(lado, 0, lado, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Paleta.suave(Paleta.peligro, 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Paleta.peligro.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Paleta.peligro, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error!,
                          style: TextStyle(color: Paleta.peligro, fontWeight: FontWeight.w600, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: angosta ? 12 : 16, vertical: 10),
              decoration: BoxDecoration(
                color: Paleta.superficie,
                border: Border(top: BorderSide(color: Paleta.bordeSuave)),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: acciones,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cabecera de los diálogos: degradé verde salvia (o del [tono] / rojo en bajas), surcos suaves,
/// ícono en un recuadro translúcido, título en blanco, rayita dorada abajo y botón de cerrar.
class CabeceraDialogo extends StatelessWidget {
  const CabeceraDialogo({super.key, required this.titulo, required this.icono, required this.tono, this.subtitulo});

  final String titulo;
  final IconData icono;
  final Color tono;
  final String? subtitulo;

  /// Colores del degradé: fijos para el verde y el rojo; para otro tono, oscurecido (así el blanco
  /// se lee también de noche, cuando los tonos son más claros).
  static List<Color> degrade(Color tono) {
    if (tono == Paleta.peligro) return const [Color(0xFF7A1A1A), Color(0xFFB3261E)];
    if (tono == Paleta.verde || tono == Paleta.verdeOscuro || tono == Paleta.verdeTitulo) {
      return const [Color(0xFF2E6B52), Color(0xFF4F8B6F)];
    }
    final base = Paleta.oscuro ? Color.lerp(tono, Colors.black, 0.3)! : tono;
    return [Color.lerp(base, Colors.black, 0.3)!, base];
  }

  @override
  Widget build(BuildContext context) {
    final rojo = tono == Paleta.peligro;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: degrade(tono)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _Surcos())),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                      ),
                      child: Icon(icono, size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.1,
                            ),
                          ),
                          if (subtitulo != null)
                            Text(
                              subtitulo!,
                              style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85)),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        hoverColor: Colors.white.withValues(alpha: 0.22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 2, color: rojo ? const Color(0x55FFFFFF) : const Color(0xFFDCC48A)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Surcos curvos muy suaves sobre el degradé (como los del logo).
class _Surcos extends CustomPainter {
  const _Surcos();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.06);
    for (var i = 0; i < 6; i++) {
      final y = size.height * (0.35 + i * 0.16);
      canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.35, y + 30)
          ..quadraticBezierTo(size.width * 0.7, y - 40 - i * 4, size.width + 20, y - 18),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bloque de formulario (estilo `SeccionFormulario`): superficie con borde fino y rótulo con línea.
class SeccionForm extends StatelessWidget {
  const SeccionForm({super.key, required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Paleta.borde),
        boxShadow: Sombras.suave,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  titulo.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Paleta.verdeTitulo,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: Paleta.dual(0xFFDDEBE1, 0xFF232D26),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Fila de campos que pasa a columna en pantallas angostas.
class FilaCampos extends StatelessWidget {
  const FilaCampos(this.hijos, {super.key, this.minimo = 560});

  final List<(int, Widget)> hijos;
  final double minimo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < minimo) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < hijos.length; i++) ...[if (i > 0) const SizedBox(height: 12), hijos[i].$2],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < hijos.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(flex: hijos[i].$1, child: hijos[i].$2),
            ],
          ],
        );
      },
    );
  }
}

final formatoMayusculas = TextInputFormatter.withFunction((_, n) => n.copyWith(text: n.text.toUpperCase()));

InputDecoration decoCampo(String etiqueta, {String? pista, bool soloLectura = false, Color? acento}) {
  OutlineInputBorder borde(Color c, double ancho) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: c, width: ancho),
  );
  return InputDecoration(
    labelText: etiqueta,
    hintText: pista,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    filled: true,
    fillColor: soloLectura ? Paleta.superficieHundida : Paleta.superficie,
    border: borde(Paleta.borde, 1),
    enabledBorder: borde(acento?.withValues(alpha: 0.6) ?? Paleta.borde, 1),
    focusedBorder: borde(acento ?? Paleta.verde, 1.4),
    floatingLabelStyle: TextStyle(color: acento ?? Paleta.verde, fontWeight: FontWeight.w600),
  );
}

enum TipoCampo { texto, decimal, entero }

Widget campoTexto(
  TextEditingController c,
  String etiqueta, {
  String? pista,
  TipoCampo tipo = TipoCampo.texto,
  bool soloLectura = false,
  bool mayusculas = false,
  bool autofoco = false,
  Color? acento,
  ValueChanged<String>? alCambiar,
  ValueChanged<String>? alEnviar,
  FocusNode? foco,
}) {
  final numerico = tipo != TipoCampo.texto;
  return TextField(
    controller: c,
    readOnly: soloLectura,
    autofocus: autofoco,
    onChanged: alCambiar,
    onSubmitted: alEnviar,
    focusNode: foco,
    textAlign: numerico ? TextAlign.right : TextAlign.start,
    style: TextStyle(
      fontSize: 13.5,
      fontWeight: numerico ? FontWeight.w600 : FontWeight.w400,
      color: soloLectura ? Paleta.tintaSuave : Paleta.tinta,
      fontFeatures: numerico ? const [FontFeature.tabularFigures()] : null,
    ),
    keyboardType: numerico ? TextInputType.numberWithOptions(decimal: tipo == TipoCampo.decimal) : null,
    textCapitalization: mayusculas ? TextCapitalization.characters : TextCapitalization.none,
    inputFormatters: [
      if (numerico) EntradaDecimal(decimales: tipo == TipoCampo.decimal),
      if (mayusculas) formatoMayusculas,
    ],
    decoration: decoCampo(etiqueta, pista: pista, soloLectura: soloLectura, acento: acento),
  );
}

/// Valor grande y destacado (stock disponible, pendiente, kilos calculados).
class DatoDestacado extends StatelessWidget {
  const DatoDestacado({super.key, required this.etiqueta, required this.valor, this.detalle, this._color});

  final String etiqueta;
  final String valor;

  /// Línea chica debajo del valor (p. ej. el equivalente en pesos).
  final String? detalle;
  final Color? _color;
  Color get color => _color ?? Paleta.verde;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Paleta.suave(color, 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Paleta.tintaSuave, letterSpacing: 0.5),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (detalle != null)
            Text(
              detalle!,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Paleta.tintaSuave,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

mixin GuardadoDialogo<T extends StatefulWidget> on State<T> {
  String? error;
  bool guardando = false;

  void fallar(String mensaje) => setState(() => error = mensaje);

  /// Corre la acción de guardado y cierra el diálogo devolviendo su resultado (mensaje u objeto guardado).
  /// Si falla, deja el error a la vista y el diálogo abierto.
  Future<void> ejecutar<R>(Future<R> Function() accion) async {
    setState(() {
      error = null;
      guardando = true;
    });
    try {
      final resultado = await accion();
      if (mounted) Navigator.pop(context, resultado);
    } catch (e) {
      if (mounted) setState(() => error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  Widget botonGuardar(String texto, VoidCallback? alTocar, {Color? color, IconData icono = Icons.check_rounded}) =>
      FilledButton.icon(
        style: color == null ? null : FilledButton.styleFrom(backgroundColor: color),
        onPressed: guardando ? null : alTocar,
        icon: guardando
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icono, size: 18),
        label: Text(guardando ? 'Guardando…' : texto),
      );

  Widget botonCancelar() =>
      TextButton(onPressed: guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar'));
}

/// Confirmación genérica (reemplaza a AgroUI.confirmar). Devuelve true si se aceptó.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String? detalle,
  String textoOk = 'Aceptar',
  bool peligro = false,
}) async {
  final tono = peligro ? Paleta.peligro : Paleta.oro;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => MarcoDialogo(
      titulo: titulo,
      icono: peligro ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
      tono: tono,
      anchoMaximo: 460,
      acciones: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: peligro ? Paleta.peligro : Paleta.verde),
          onPressed: () => Navigator.pop(context, true),
          child: Text(textoOk),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mensaje, style: const TextStyle(height: 1.45)),
          if (detalle != null && detalle.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Paleta.superficie,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tono.withValues(alpha: 0.35)),
              ),
              child: Text(detalle, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    ),
  );
  return ok ?? false;
}

/// Pide un texto corto (p. ej. un rubro nuevo). Devuelve null si se canceló o quedó vacío.
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  String? pista,
}) async {
  final c = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (context) {
      void aceptar() => Navigator.pop(context, c.text.trim());
      return MarcoDialogo(
        titulo: titulo,
        icono: Icons.add_rounded,
        tono: Paleta.verde,
        anchoMaximo: 440,
        acciones: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: aceptar, child: const Text('Agregar')),
        ],
        child: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [formatoMayusculas],
          onSubmitted: (_) => aceptar(),
          decoration: decoCampo(etiqueta, pista: pista),
        ),
      );
    },
  );
  c.dispose();
  return (r == null || r.isEmpty) ? null : r.toUpperCase();
}
