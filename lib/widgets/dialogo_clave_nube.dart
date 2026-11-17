import 'package:flutter/material.dart';

import '../core/tema/paleta.dart';

/// Pide la contraseña de Supabase para sincronizar (no guarda nada).
Future<({String correo, String clave})?> pedirClaveNube(
  BuildContext context, {
  required String correo,
  required String error,
}) {
  return showDialog<({String correo, String clave})>(
    context: context,
    builder: (_) => _DialogoClaveNube(correo: correo, error: error),
  );
}

class _DialogoClaveNube extends StatefulWidget {
  const _DialogoClaveNube({required this.correo, required this.error});

  final String correo;
  final String error;

  @override
  State<_DialogoClaveNube> createState() => _DialogoClaveNubeState();
}

class _DialogoClaveNubeState extends State<_DialogoClaveNube> {
  late final _correo = TextEditingController(text: widget.correo);
  final _clave = TextEditingController();
  bool _verClave = false;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  void _aceptar() {
    final c = _correo.text.trim().toLowerCase();
    final k = _clave.text;
    _clave.clear();
    Navigator.of(context).pop(c.isNotEmpty && k.isNotEmpty ? (correo: c, clave: k) : null);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: Paleta.verde.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(Icons.cloud_sync_rounded, color: Paleta.verde, size: 26),
      ),
      title: Text('Iniciar sesión en la nube', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 360,
        child: AutofillGroup(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
              'Para sincronizar, confirmá tu contraseña de Supabase.',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: Paleta.tintaSuave),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.alternate_email_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clave,
              autofocus: widget.correo.isNotEmpty,
              obscureText: !_verClave,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _aceptar(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  tooltip: _verClave ? 'Ocultar' : 'Mostrar',
                  icon: Icon(_verClave ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _verClave = !_verClave),
                ),
              ),
            ),
            if (widget.error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                widget.error,
                style: t.bodySmall?.copyWith(color: Paleta.peligro, fontWeight: FontWeight.w700),
              ),
            ],
          ]),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: _aceptar,
          icon: const Icon(Icons.sync_rounded, size: 18),
          label: const Text('Ingresar y sincronizar'),
        ),
      ],
    );
  }
}
