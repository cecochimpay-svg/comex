import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/categoria/categoria_page.dart';
import '../../features/home/home_page.dart';
import '../../features/login/login_page.dart';
import '../../features/modulo/modulo_page.dart';
import '../../features/shell/app_shell.dart';
import '../auth/sesion_controller.dart';
import 'catalogo.dart';

/// Rutas:
///   /login       ingreso
///   /            menú principal
///   /c/:clave    submenú de una categoría
///   /m/:ref      pantalla de un módulo (misma referencia que render.js, p. ej. /m/PROD_ACOPIO)
GoRouter crearRouter(SesionController sesion) {
  return GoRouter(
    initialLocation: rutaInicial,
    refreshListenable: sesion,
    redirect: (context, state) {
      final logueado = sesion.actual != null;
      final enLogin = state.matchedLocation == '/login';
      if (!logueado) return enLogin ? null : '/login';
      return enLogin ? rutaInicial : null; // después del login, Vuelos (como la versión Electron)
    },
    routes: [
      GoRoute(path: '/login', pageBuilder: (context, state) => _transicion(state, const LoginPage())),
      ShellRoute(
        builder: (context, state, child) => AppShell(ruta: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (context, state) => _transicion(state, const HomePage())),
          GoRoute(
            path: '/c/:clave',
            pageBuilder: (context, state) => _transicion(state, CategoriaPage(clave: state.pathParameters['clave']!)),
          ),
          GoRoute(
            path: '/m/:ref',
            pageBuilder: (context, state) => _transicion(state, ModuloPage(referencia: state.pathParameters['ref']!)),
          ),
        ],
      ),
    ],
  );
}

CustomTransitionPage<void> _transicion(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animacion, secundaria, child) {
      final curva = CurvedAnimation(parent: animacion, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curva,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.012), end: Offset.zero).animate(curva),
          child: child,
        ),
      );
    },
  );
}
