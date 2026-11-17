import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/sesion_controller.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/comunes.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Paleta.fondo,
      body: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 920) {
          return Row(children: [
            const Expanded(flex: 11, child: _PanelMarca()),
            Expanded(
              flex: 9,
              child: Center(
                child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: const _Formulario()),
              ),
            ),
          ]);
        }
        return SingleChildScrollView(
          child: Column(children: [
            const _BandaMarca(),
            Padding(padding: const EdgeInsets.fromLTRB(20, 28, 20, 32), child: const _Formulario()),
          ]),
        );
      }),
    );
  }
}

// -----------------------------------------------------------------------------
// Formulario
// -----------------------------------------------------------------------------
class _Formulario extends StatefulWidget {
  const _Formulario();

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  final _focoClave = FocusNode();
  bool _verClave = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    _focoClave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (_cargando) return;
    final usuario = _usuario.text.trim();
    final clave = _clave.text;
    if (usuario.isEmpty || clave.isEmpty) {
      setState(() => _error = 'Completá el usuario y la contraseña para continuar.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    final r = await context.read<SesionController>().iniciarSesion(usuario, clave);
    if (!mounted) return;
    _clave.clear();
    // Si entró, el enrutador lleva solo al menú principal.
    if (!r.ok) {
      setState(() {
        _cargando = false;
        _error = r.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          const Align(alignment: Alignment.centerLeft, child: LogoComex(tamano: 58)),
          const SizedBox(height: 26),
          Text('Bienvenido', style: t.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          const SizedBox(height: 6),
          Text(
            'Ingresá con tu usuario de COMEX.',
            style: t.bodyLarge?.copyWith(color: Paleta.tintaSuave),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Paleta.verdeSuave,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified_user_rounded, size: 14, color: Paleta.verde),
                SizedBox(width: 6),
                Text(
                  'ACCESO SEGURO · FUNCIONA SIN INTERNET',
                  style: TextStyle(color: Paleta.verde, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _usuario,
            enabled: !_cargando,
            autofocus: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            onSubmitted: (_) => _focoClave.requestFocus(),
            decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person_rounded)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _clave,
            focusNode: _focoClave,
            enabled: !_cargando,
            obscureText: !_verClave,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _ingresar(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                tooltip: _verClave ? 'Ocultar contraseña' : 'Mostrar contraseña',
                icon: Icon(_verClave ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => _verClave = !_verClave),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Paleta.suave(Paleta.peligro, 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Paleta.peligro.withValues(alpha: 0.25)),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_rounded, color: Paleta.peligro, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Paleta.peligro, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ]),
                    ),
                  ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: _cargando ? null : _ingresar,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _cargando
                    ? const Row(key: ValueKey('cargando'), mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Verificando credenciales…'),
                      ])
                    : const Row(key: ValueKey('listo'), mainAxisSize: MainAxisSize.min, children: [
                        Text('Ingresar al sistema'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ]),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 14),
          const FirmaAgrosoft(centrada: true),
        ]),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Marca
// -----------------------------------------------------------------------------
/// Degradé de marca: igual en los dos modos (como la barra de arriba).
const _degradeMarca = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Paleta.bosque, Paleta.marca, Color(0xFF1E6B4C)],
  stops: [0, 0.55, 1],
);

class _PanelMarca extends StatelessWidget {
  const _PanelMarca();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: _degradeMarca),
      child: Stack(children: [
        const Positioned.fill(child: CustomPaint(painter: _CurvasDeNivel())),
        const Positioned(left: 0, top: 0, bottom: 0, width: 6, child: _RielDorado(vertical: true)),
        LayoutBuilder(builder: (context, c) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(60, 48, 56, 40),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      LogoComex(tamano: 46),
                      SizedBox(width: 14),
                      Text(
                        'COMEX',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 2.4),
                      ),
                    ]),
                    const Spacer(),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Paleta.trigo.withValues(alpha: 0.35)),
                      ),
                      child: const Text(
                        'COMERCIO EXTERIOR',
                        style: TextStyle(color: Paleta.trigo, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Cada programa,\nbajo control.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 46,
                        height: 1.08,
                        letterSpacing: -1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 470),
                      child: Text(
                        'Programá los despachos aéreos y los programas de empaque por cliente — aún sin internet. '
                        'Todo se sincroniza solo cuando volvés a estar en línea.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 15.5, height: 1.55),
                      ),
                    ),
                    const SizedBox(height: 34),
                    const _Rasgo(icono: Icons.verified_user_rounded, texto: 'Acceso seguro con tu usuario de COMEX'),
                    const _Rasgo(icono: Icons.flight_takeoff_rounded, texto: 'Despachos con el formato de la planilla de logística'),
                    const _Rasgo(icono: Icons.sync_rounded, texto: 'Sincronización con COMEX Despachos'),
                    const Spacer(),
                    const SizedBox(height: 40),
                    Text(
                      'CECO S.A. · Comercio exterior',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ),
            ),
          );
        }),
      ]),
    );
  }
}

class _BandaMarca extends StatelessWidget {
  const _BandaMarca();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: _degradeMarca),
        child: Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _CurvasDeNivel())),
          const Positioned(left: 0, right: 0, bottom: 0, height: 4, child: _RielDorado(vertical: false)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 34),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  LogoComex(tamano: 40),
                  SizedBox(width: 12),
                  Text(
                    'COMEX',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: 2),
                  ),
                ]),
                const SizedBox(height: 28),
                const Text(
                  'Cada programa,\nbajo control.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28, height: 1.12, letterSpacing: -0.8),
                ),
                const SizedBox(height: 8),
                Text(
                  'Funciona aun sin internet.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Rasgo extends StatelessWidget {
  const _Rasgo({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, size: 18, color: Paleta.menta),
        ),
        const SizedBox(width: 13),
        Text(
          texto,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}

class _RielDorado extends StatelessWidget {
  const _RielDorado({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
          end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
          colors: [Paleta.trigo, Paleta.oro],
        ),
      ),
    );
  }
}

/// Curvas de nivel tipo mapa topográfico (textura de la marca).
class _CurvasDeNivel extends CustomPainter {
  const _CurvasDeNivel();

  @override
  void paint(Canvas canvas, Size size) {
    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    void familia(Offset centro, int cantidad, double paso, double fase, double alfa) {
      for (var i = 1; i <= cantidad; i++) {
        final radio = paso * i;
        final path = Path();
        for (var k = 0; k <= 140; k++) {
          final t = k / 140 * 2 * pi;
          final onda = 1 + 0.07 * sin(3 * t + fase + i * 0.35) + 0.04 * sin(5 * t - fase * 1.7 + i * 0.2);
          final x = centro.dx + cos(t) * radio * 1.3 * onda;
          final y = centro.dy + sin(t) * radio * onda;
          if (k == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        trazo.color = Colors.white.withValues(alpha: alfa * (1 - i / (cantidad + 3)));
        canvas.drawPath(path, trazo);
      }
    }

    final lado = size.shortestSide;
    familia(Offset(size.width * 0.84, size.height * 0.2), 16, lado * 0.065, 0.4, 0.17);
    familia(Offset(size.width * 0.02, size.height * 0.98), 12, lado * 0.075, 1.9, 0.11);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
