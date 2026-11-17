import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/sesion_controller.dart';
import '../../core/config.dart';
import '../../core/nav/catalogo.dart';
import '../../core/tema/modo_tema.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/comunes.dart';
import 'boton_sincronizar.dart';
import 'buscador_pantallas.dart';
import 'menus_area.dart';

export 'menus_area.dart' show CardPantalla;

/// Barra de arriba con el degradé de marca: igual en los dos modos.
const _fondoBarra = BoxDecoration(gradient: Paleta.barraArriba);

/// Barra de navegación superior (escritorio / tablet): marca, una pestaña por área con su panel de cards,
/// buscador de pantallas, sincronizar y menú del usuario.
class BarraNavegacion extends StatelessWidget {
  const BarraNavegacion({super.key, required this.ruta});

  static const alto = 52.0;

  final String ruta;

  @override
  Widget build(BuildContext context) {
    final amplia = MediaQuery.sizeOf(context).width >= 1240;
    final activa = categoriaDeRuta(ruta);
    return Container(
      height: alto,
      decoration: _fondoBarra,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _Marca(conTexto: amplia, tamano: 32),
          const SizedBox(width: 14),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Pestana(
                    texto: 'Inicio',
                    icono: Icons.space_dashboard_rounded,
                    conIcono: amplia,
                    activa: ruta == '/',
                    onTap: () => context.go('/'),
                  ),
                  for (final c in categorias) _PestanaArea(categoria: c, activa: activa == c, conIcono: amplia),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          const _BotonBuscar(),
          const SizedBox(width: 6),
          const BotonModoTema(),
          const SizedBox(width: 8),
          BotonSincronizar(compacto: !amplia),
          const SizedBox(width: 10),
          _MenuUsuario(conNombre: amplia),
        ],
      ),
    );
  }
}

/// Barra superior del celular: marca, título de la pantalla actual, buscar, sincronizar y usuario.
class BarraMovil extends StatelessWidget {
  const BarraMovil({super.key, required this.ruta});

  final String ruta;

  @override
  Widget build(BuildContext context) {
    final titulo = ruta.startsWith('/m/')
        ? indicePantallas[ruta.substring(3)]?.pantalla.titulo
        : categoriaDeRuta(ruta)?.titulo;
    return Container(
      height: 52,
      decoration: _fondoBarra,
      padding: const EdgeInsets.only(left: 10, right: 8),
      child: Row(
        children: [
          const _Marca(conTexto: false, tamano: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              titulo ?? 'COMEX',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          const _BotonBuscar(),
          const SizedBox(width: 6),
          const BotonSincronizar(compacto: true),
          const SizedBox(width: 6),
          const _MenuUsuario(conNombre: false),
        ],
      ),
    );
  }
}

/// Barra inferior del celular: Inicio, las primeras áreas y "Más" con el resto.
class NavegacionInferior extends StatelessWidget {
  const NavegacionInferior({super.key, required this.ruta});

  static const _areasFijas = 3;

  final String ruta;

  @override
  Widget build(BuildContext context) {
    final fijas = categorias.take(_areasFijas).toList();
    final resto = categorias.skip(_areasFijas).toList();
    final activa = categoriaDeRuta(ruta);
    final indice = ruta == '/'
        ? 0
        : activa == null
        ? 0
        : (fijas.contains(activa) ? fijas.indexOf(activa) + 1 : fijas.length + 1);

    // La pastilla de la pestaña elegida toma el color de su área.
    final tonoActivo = indice >= 1 && indice <= fijas.length ? fijas[indice - 1].tono : Paleta.verde;
    final barra = NavigationBar(
      selectedIndex: indice,
      height: 62,
      backgroundColor: Paleta.superficie,
      indicatorColor: Paleta.suave(tonoActivo, 0.14),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (i) {
        if (i == 0) return context.go('/');
        if (i <= fijas.length) return context.go(rutaCategoria(fijas[i - 1]));
        _mostrarMas(context, resto);
      },
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          selectedIcon: Icon(Icons.space_dashboard_rounded, color: Paleta.verde),
          label: 'Inicio',
        ),
        for (final c in fijas)
          NavigationDestination(
            icon: Icon(c.icono),
            selectedIcon: Icon(c.icono, color: c.tono),
            label: c.titulo,
          ),
        NavigationDestination(
          icon: Icon(Icons.apps_rounded),
          selectedIcon: Icon(Icons.apps_rounded, color: Paleta.verde),
          label: 'Más',
        ),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Paleta.borde)),
        boxShadow: Sombras.suave,
      ),
      child: barra,
    );
  }

  void _mostrarMas(BuildContext context, List<Categoria> resto) => mostrarHojaMas(context, resto);
}

class _Marca extends StatelessWidget {
  const _Marca({required this.conTexto, this.tamano = 38});

  final bool conTexto;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Inicio',
      child: InkWell(
        onTap: () => context.go('/'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LogoComex(tamano: tamano),
              if (conTexto) ...[
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'COMEX',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'GESTIÓN AGRO',
                      style: TextStyle(
                        color: Paleta.trigo,
                        fontWeight: FontWeight.w700,
                        fontSize: 9.5,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pestaña de la barra: texto claro sobre el bosque; la activa con fondo y subrayado trigo.
class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.texto,
    required this.icono,
    required this.onTap,
    this.conIcono = true,
    this.activa = false,
    this.abierta = false,
    this.desplegable = false,
  });

  final String texto;
  final IconData icono;
  final VoidCallback onTap;
  final bool conIcono;
  final bool activa;
  final bool abierta;
  final bool desplegable;

  @override
  Widget build(BuildContext context) {
    final resaltada = activa || abierta;
    final color = resaltada ? Colors.white : Paleta.navTexto;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: resaltada ? Colors.white.withValues(alpha: 0.11) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.07),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: activa ? Paleta.trigo : Colors.transparent, width: 2.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (conIcono) ...[Icon(icono, size: 16, color: color), const SizedBox(width: 6)],
                Text(
                  texto,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (desplegable) ...[
                  const SizedBox(width: 3),
                  AnimatedRotation(
                    turns: abierta ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.expand_more_rounded, size: 17, color: color),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pestaña de un área: si tiene varias pantallas abre un panel de cards; si tiene una, va directo.
class _PestanaArea extends StatelessWidget {
  const _PestanaArea({required this.categoria, required this.activa, required this.conIcono});

  final Categoria categoria;
  final bool activa;
  final bool conIcono;

  @override
  Widget build(BuildContext context) {
    final c = categoria;
    if (c.pantallas.length == 1) {
      return _Pestana(
        texto: c.titulo,
        icono: c.icono,
        conIcono: conIcono,
        activa: activa,
        onTap: () => context.go(rutaCategoria(c)),
      );
    }
    return MenuAnchor(
      alignmentOffset: const Offset(0, 10),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Paleta.fondo),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(14),
        shadowColor: const WidgetStatePropertyAll(Color(0x590A140E)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Paleta.borde),
          ),
        ),
      ),
      menuChildren: [PanelAreaMenu(categoria: c)],
      builder: (context, menu, _) => _Pestana(
        texto: c.titulo,
        icono: c.icono,
        conIcono: conIcono,
        activa: activa,
        abierta: menu.isOpen,
        desplegable: true,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

class _BotonBuscar extends StatelessWidget {
  const _BotonBuscar();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Buscar pantalla (Ctrl+K)',
      onPressed: () => mostrarBuscadorPantallas(context),
      icon: const Icon(Icons.search_rounded, color: Colors.white, size: 19),
      style: _estiloPildora,
    );
  }
}

/// Avatar con iniciales: abre los datos de la sesión y "Cerrar sesión".
class _MenuUsuario extends StatelessWidget {
  const _MenuUsuario({required this.conNombre});

  final bool conNombre;

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionController>().actual;
    final avatar = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Paleta.verdeClaro, Paleta.verde]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Text(
        sesion?.iniciales ?? '—',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Paleta.superficie),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(14),
        shadowColor: const WidgetStatePropertyAll(Color(0x590A140E)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Paleta.borde)),
        ),
      ),
      menuChildren: [
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ficha del usuario sobre el verde de marca.
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: const BoxDecoration(gradient: Paleta.barraArriba),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Color(0xFF4CC28A), Color(0xFF1E6B4C)]),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                      ),
                      child: Text(
                        sesion?.iniciales ?? '—',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sesion?.nombre ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Colors.white),
                          ),
                          if ((sesion?.correo ?? '').isNotEmpty)
                            Text(
                              sesion!.correo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Paleta.navTexto),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Etiqueta(texto: sesion?.rolEtiqueta ?? '', color: Paleta.verde),
                        _Etiqueta(
                          texto: (sesion?.offline ?? true) ? 'Modo local' : 'En línea',
                          color: (sesion?.offline ?? true) ? Paleta.pizarra : Paleta.exito,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const LedPulso(),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Local-first · ${Config.appVersion}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Paleta.tintaTenue, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const FirmaAgrosoft(),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: Icon(Icons.search_rounded, size: 18, color: Paleta.tintaSuave),
          trailingIcon: Text('Ctrl K', style: TextStyle(fontSize: 11, color: Paleta.tintaTenue)),
          onPressed: () => mostrarBuscadorPantallas(context),
          child: const Text('Buscar pantalla'),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            Paleta.oscuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 18,
            color: Paleta.tintaSuave,
          ),
          onPressed: () => context.read<ModoTema>().alternar(),
          child: Text(Paleta.oscuro ? 'Modo día' : 'Modo noche'),
        ),
        MenuItemButton(
          leadingIcon: Icon(Icons.logout_rounded, size: 18, color: Paleta.peligro),
          onPressed: () => context.read<SesionController>().cerrarSesion(),
          child: Text(
            'Cerrar sesión',
            style: TextStyle(color: Paleta.peligro, fontWeight: FontWeight.w700),
          ),
        ),
      ],
      builder: (context, menu, _) => InkWell(
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              avatar,
              if (conNombre && sesion != null) ...[
                const SizedBox(width: 9),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sesion.primerNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Text(sesion.rolEtiqueta, style: const TextStyle(color: Paleta.navTenue, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more_rounded, size: 18, color: Paleta.navTexto),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
    child: Text(
      texto.toUpperCase(),
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
    ),
  );
}

/// Botones redondeados translúcidos de la barra de arriba (como las píldoras del panel de oficina).
final _estiloPildora = IconButton.styleFrom(
  fixedSize: const Size(34, 32),
  minimumSize: const Size(34, 32),
  padding: EdgeInsets.zero,
  backgroundColor: Colors.white.withValues(alpha: 0.12),
  hoverColor: Colors.white.withValues(alpha: 0.22),
  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
);

/// Alterna modo día / noche: el modo nuevo se abre en círculo desde el botón.
class BotonModoTema extends StatelessWidget {
  const BotonModoTema({super.key});

  @override
  Widget build(BuildContext context) {
    final oscuro = Paleta.oscuro;
    return IconButton(
      tooltip: oscuro ? 'Pasar a modo día' : 'Pasar a modo noche',
      onPressed: () {
        final caja = context.findRenderObject() as RenderBox?;
        context.read<ModoTema>().alternar(desde: caja?.localToGlobal(caja.size.center(Offset.zero)));
      },
      icon: Icon(oscuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: Colors.white, size: 18),
      style: _estiloPildora,
    );
  }
}
