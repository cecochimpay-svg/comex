import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/auth/sesion_controller.dart';
import 'core/nav/router.dart';
import 'core/registro/registro.dart';
import 'core/tema/modo_tema.dart';
import 'core/tema/tema.dart';
import 'widgets/revelar_cambio.dart';

class ComexApp extends StatefulWidget {
  const ComexApp({super.key, required this.sesion});

  final SesionController sesion;

  @override
  State<ComexApp> createState() => _ComexAppState();
}

class _ComexAppState extends State<ComexApp> with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    anotar('ComexApp: inicializando GoRouter y observador de sistema.');
    _router = crearRouter(widget.sesion);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangePlatformBrightness() {
    context.read<ModoTema>().sistemaCambio(WidgetsBinding.instance.platformDispatcher.platformBrightness);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ModoTema>(); // el tema sale del modo actual
    final tema = temaComex();

    return MaterialApp.router(
      key: const ValueKey('comex_app_material_root'),
      title: 'COMEX',
      debugShowCheckedModeBanner: false,
      theme: tema,
      // El cambio de modo lo anima el revelado en círculo, no una transición de colores.
      themeAnimationDuration: Duration.zero,
      builder: (context, child) {
        // En Windows de escritorio, si GoRouter resuelve la ruta inicial sin sesión,
        // child puede ser nulo en el primer pulso. Se asegura siempre un fondo opaco.
        final contenido =
            child ?? Scaffold(backgroundColor: tema.scaffoldBackgroundColor, body: const SizedBox.expand());

        return Material(color: tema.scaffoldBackgroundColor, child: RevelarCambio.envolver(contenido));
      },
      routerConfig: _router,
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
