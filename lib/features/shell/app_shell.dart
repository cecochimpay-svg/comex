import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'barra_navegacion.dart';
import 'buscador_pantallas.dart';
import 'panel_avisos.dart';

/// Armazón de la app: barra de navegación superior + contenido a todo el ancho.
///   - Escritorio / tablet: una pestaña por área; cada una despliega sus pantallas como cards.
///   - Celular: barra superior compacta y barra inferior con las áreas ("Más" para el resto).
///   - Ctrl+K abre el buscador de pantallas desde cualquier lugar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.ruta, required this.child});

  static const anchoCelular = 760.0;

  final String ruta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final celular = MediaQuery.sizeOf(context).width < anchoCelular;

    final Widget cuerpo = celular
        ? Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  BarraMovil(ruta: ruta),
                  Expanded(child: child),
                ],
              ),
            ),
            bottomNavigationBar: NavegacionInferior(ruta: ruta),
          )
        : Scaffold(
            body: Column(
              children: [
                BarraNavegacion(ruta: ruta),
                Expanded(child: child),
              ],
            ),
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => mostrarBuscadorPantallas(context),
      },
      child: Focus(
        autofocus: true,
        // Avisos de cambios para el ADM, flotando arriba a la derecha sobre cualquier pantalla.
        child: Stack(
          children: [
            Positioned.fill(child: cuerpo),
            Positioned(
              top: celular ? MediaQuery.paddingOf(context).top + 64 : 74,
              right: 12,
              child: const PanelAvisos(),
            ),
          ],
        ),
      ),
    );
  }
}
