import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/nav/catalogo.dart';
import '../../core/preferencias.dart';
import '../../core/tema/paleta.dart';
import '../../core/auth/sesion_controller.dart';
import '../../widgets/comunes.dart';
import '../programa/programa_page.dart';
import '../vuelos/vuelos_page.dart';

/// Pantalla de un módulo: abre la versión portada si existe; si no, el aviso de migración.
class ModuloPage extends StatefulWidget {
  const ModuloPage({super.key, required this.referencia});

  final String referencia;

  @override
  State<ModuloPage> createState() => _ModuloPageState();
}

class _ModuloPageState extends State<ModuloPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<Preferencias>().registrarReciente(widget.referencia);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ubicacion = indicePantallas[widget.referencia];
    if (ubicacion == null) return const _NoEncontrada();
    // Pantallas de ADM (Programa): un usuario COMEX que llega por la URL vuelve a Vuelos.
    if (!ubicacion.pantalla.permitidaPara(context.watch<SesionController>().actual)) {
      return const _NoEncontrada();
    }
    switch (widget.referencia) {
      case 'VUELOS':
        return VuelosPage(ubicacion: ubicacion);
      case 'PROGRAMA':
        return ProgramaPage(ubicacion: ubicacion);
    }
    final c = ubicacion.categoria;
    final p = ubicacion.pantalla;

    return PaginaContenido(
      anchoMaximo: 1320,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EncabezadoModulo(categoria: c, pantalla: p, acciones: [BotonVolver(categoria: c)]),
        const SizedBox(height: 20),
        _AvisoMigracion(pantalla: p, tono: c.tono),
      ]),
    );
  }
}

/// Encabezado de cada módulo (estilo oficina): ícono del área en un cuadradito con degradé, área en
/// mayúsculas, título y descripción; las acciones a la derecha (abajo en pantallas angostas).
class EncabezadoModulo extends StatelessWidget {
  const EncabezadoModulo({super.key, required this.categoria, required this.pantalla, this.acciones = const []});

  final Categoria categoria;
  final Pantalla pantalla;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final tono = categoria.tono;
    final angosta = MediaQuery.sizeOf(context).width < 600;
    final textos = Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Paleta.suave(tono, 0.10), Paleta.suave(tono, 0.20)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tono.withValues(alpha: 0.22)),
        ),
        child: Icon(pantalla.icono, color: tono, size: 20),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(
            categoria.titulo.toUpperCase(),
            style: TextStyle(color: tono, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.9),
          ),
          Text(
            pantalla.titulo,
            style: TextStyle(
              color: Paleta.verdeTitulo,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.2,
            ),
          ),
          Text(
            pantalla.descripcion,
            maxLines: angosta ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Paleta.tintaSuave, fontSize: 12),
          ),
        ]),
      ),
    ]);
    return Container(
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Paleta.borde),
        boxShadow: Sombras.suave,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(left: 0, top: 0, bottom: 0, width: 3, child: ColoredBox(color: tono)),
        Padding(
          padding: EdgeInsets.fromLTRB(angosta ? 14 : 18, 12, angosta ? 12 : 14, 12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            spacing: 12,
            children: [
              textos,
              if (acciones.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: acciones),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Vuelve al submenú de la categoría (o al inicio si la categoría tiene una sola pantalla).
class BotonVolver extends StatelessWidget {
  const BotonVolver({super.key, required this.categoria});

  final Categoria categoria;

  @override
  Widget build(BuildContext context) {
    final submenu = categoria.pantallas.length > 1;
    return BotonHero(
      icono: Icons.arrow_back_rounded,
      texto: submenu ? categoria.titulo : 'Inicio',
      onTap: () => context.go(submenu ? '/c/${categoria.clave}' : '/'),
    );
  }
}

/// Botón del encabezado: con borde fino (como `BotonBorde` de oficina) o, si es la acción principal,
/// verde lleno que al pasar el mouse se oscurece y se despega con una sombra.
class BotonHero extends StatelessWidget {
  const BotonHero({super.key, required this.icono, required this.texto, required this.onTap, this.principal = false});

  final IconData icono;
  final String texto;
  final VoidCallback? onTap;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    if (principal) {
      final color = Paleta.verde;
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icono, size: 16),
        label: Text(texto),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shadowColor: color.withValues(alpha: 0.45),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return Paleta.borde;
            if (!s.contains(WidgetState.hovered)) return color;
            return Color.lerp(color, Colors.black, 0.18);
          }),
          elevation: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? 0 : (s.contains(WidgetState.hovered) ? 4 : 0),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icono, size: 16),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        foregroundColor: Paleta.tinta,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.hovered) ? Paleta.superficieSuave : Paleta.superficie,
        ),
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(color: s.contains(WidgetState.hovered) ? Paleta.verdeLinea : Paleta.borde),
        ),
      ),
    );
  }
}

class _AvisoMigracion extends StatelessWidget {
  const _AvisoMigracion({required this.pantalla, required this.tono});

  final Pantalla pantalla;
  final Color tono;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Paleta.borde),
        boxShadow: Sombras.suave,
      ),
      child: Column(children: [
        IconoTono(icono: Icons.construction_rounded, tono: tono, tamano: 64),
        const SizedBox(height: 18),
        Text('Pantalla en migración', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'La pantalla de ${pantalla.titulo} se está pasando a la nueva versión. '
            'Mientras tanto seguí cargando datos en la versión de escritorio: '
            'todo lo que sincronices ya queda disponible en esta base local.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: Paleta.tintaSuave, height: 1.5),
          ),
        ),
      ]),
    );
  }
}

class _NoEncontrada extends StatelessWidget {
  const _NoEncontrada();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconoTono(icono: Icons.explore_off_rounded, tono: Paleta.pizarra, tamano: 60),
        const SizedBox(height: 16),
        Text('No encontramos esa pantalla', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_rounded, size: 18),
          label: const Text('Menú principal'),
        ),
      ]),
    );
  }
}
