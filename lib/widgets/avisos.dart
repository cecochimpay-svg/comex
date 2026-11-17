import 'package:flutter/material.dart';

import '../core/tema/paleta.dart';

enum TipoAviso { exito, aviso, error }

/// Aviso flotante (reemplaza al toast de la versión de escritorio), como `avisoOficina`:
/// superficie con borde fino, rayita e ícono del color del tipo.
void mostrarAviso(BuildContext context, String mensaje, {TipoAviso tipo = TipoAviso.exito}) {
  final (color, icono) = switch (tipo) {
    TipoAviso.exito => (Paleta.exito, Icons.check_circle_outline_rounded),
    TipoAviso.aviso => (Paleta.oro, Icons.info_outline_rounded),
    TipoAviso.error => (Paleta.peligro, Icons.error_outline_rounded),
  };
  final ancho = MediaQuery.sizeOf(context).width;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating, // requerido para fijar el ancho
        width: ancho > 640 ? 440 : null,
        elevation: 6,
        backgroundColor: Paleta.superficie,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Paleta.borde),
        ),
        content: Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Icon(icono, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mensaje,
                style: TextStyle(color: Paleta.tinta, fontWeight: FontWeight.w500, fontSize: 13, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
}
