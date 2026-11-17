import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/nav/catalogo.dart';
import '../../core/tema/modo_tema.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/comunes.dart';
import '../categoria/categoria_page.dart' show coloresCabeceraArea;
import '../home/piezas_menu.dart';
import '../home/resumen_datos.dart';
import '../home/resumen_repo.dart';
import 'buscador_pantallas.dart';

/// Menús de la barra: el desplegable de cada área (escritorio) y la hoja "Más" (celular), con la misma
/// tarjeta de pantalla y el dato vivo de cada una.

/// Card de una pantalla: ícono del área, título, descripción y (si hay) su dato vivo.
class CardPantalla extends StatelessWidget {
  const CardPantalla({
    super.key,
    required this.pantalla,
    required this.tono,
    required this.onTap,
    this.activa = false,
    this.dato,
  });

  final Pantalla pantalla;
  final Color tono;
  final VoidCallback onTap;
  final bool activa;

  /// Dato vivo corto ("3 remitos este mes").
  final String? dato;

  @override
  Widget build(BuildContext context) {
    return Presionable(
      etiqueta: pantalla.titulo,
      onTap: onTap,
      builder: (context, resaltado) => AnimatedContainer(
        duration: sinAnimaciones(context) ? Duration.zero : const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: activa ? Paleta.suave(tono, 0.08) : (resaltado ? Paleta.filaHover : Paleta.superficie),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: resaltado || activa ? tono.withValues(alpha: 0.5) : Paleta.borde),
          boxShadow: resaltado ? Sombras.media : Sombras.suave,
        ),
        child: Row(
          children: [
            IconoVivo(icono: pantalla.icono, tono: tono, activa: resaltado || activa, tamano: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pantalla.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Paleta.tinta),
                  ),
                  Text(
                    pantalla.descripcion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Paleta.tintaSuave),
                  ),
                  if (dato != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(color: tono, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            dato!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: tono, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            AnimatedSlide(
              duration: sinAnimaciones(context) ? Duration.zero : const Duration(milliseconds: 180),
              offset: Offset(resaltado ? 0.2 : 0, 0),
              child: Icon(Icons.arrow_forward_rounded, size: 16, color: resaltado ? tono : Paleta.tintaTenue),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cabecera chica en el degradé del área (desplegables y hoja "Más").
class CabeceraMenuArea extends StatelessWidget {
  const CabeceraMenuArea({super.key, required this.categoria, this.pendientes = 0, this.alVerArea});

  final Categoria categoria;
  final int pendientes;
  final VoidCallback? alVerArea;

  @override
  Widget build(BuildContext context) {
    final c = categoria;
    final (a, b) = coloresCabeceraArea(c);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]),
      ),
      child: Stack(
        children: [
          Positioned(
            right: alVerArea == null ? -14 : 90,
            top: -22,
            child: Icon(c.icono, size: 92, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Icon(c.icono, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.titulo,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ),
                          if (pendientes > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '$pendientes sin subir',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        c.descripcion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
                if (alVerArea != null)
                  TextButton(
                    onPressed: alVerArea,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Ver área', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 15),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Contenido del desplegable de un área: cabecera en su color y sus pantallas en cards (dos columnas).
class PanelAreaMenu extends StatefulWidget {
  const PanelAreaMenu({super.key, required this.categoria});

  final Categoria categoria;

  @override
  State<PanelAreaMenu> createState() => _PanelAreaMenuState();
}

class _PanelAreaMenuState extends State<PanelAreaMenu> {
  static const _anchoCard = 280.0;

  void _ir(String ruta) {
    MenuController.maybeOf(context)?.close();
    context.go(ruta);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.categoria;
    final actual = GoRouterState.of(context).uri.path;
    final pantallas = c.pantallas;
    final columnas = pantallas.length > 1 ? 2 : 1;
    final ancho = columnas * _anchoCard + (columnas - 1) * 10;

    return ValueListenableBuilder<ResumenAreas?>(
      valueListenable: ResumenVivo.datos,
      builder: (context, r, _) => SizedBox(
        width: ancho + 24,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              CabeceraMenuArea(
                categoria: c,
                pendientes: r?.pendientesDe(c.clave) ?? 0,
                alVerArea: () => _ir('/c/${c.clave}'),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < pantallas.length; i += columnas) ...[
                if (i > 0) const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = i; j < i + columnas; j++) ...[
                        if (j > i) const SizedBox(width: 10),
                        SizedBox(
                          width: _anchoCard,
                          child: j < pantallas.length
                              ? Aparecer(
                                  orden: j,
                                  child: CardPantalla(
                                    pantalla: pantallas[j],
                                    tono: c.tono,
                                    activa: actual == rutaPantalla(pantallas[j].ref),
                                    dato: r == null ? null : datoDePantalla(pantallas[j].ref, r),
                                    onTap: () => _ir(rutaPantalla(pantallas[j].ref)),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja "Más" del celular: las áreas que no entran en la barra inferior y atajos (buscar, modo noche).
Future<void> mostrarHojaMas(BuildContext context, List<Categoria> areas) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Paleta.fondo,
    builder: (hoja) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(hoja).height * 0.85),
      child: SafeArea(
        child: ValueListenableBuilder<ResumenAreas?>(
          valueListenable: ResumenVivo.datos,
          builder: (_, r, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(padding: EdgeInsets.fromLTRB(2, 0, 0, 10), child: Rotulo('Más áreas')),
                for (final (n, c) in areas.indexed) ...[
                  if (n > 0) const SizedBox(height: 16),
                  Aparecer(
                    orden: n,
                    child: CabeceraMenuArea(categoria: c, pendientes: r?.pendientesDe(c.clave) ?? 0),
                  ),
                  for (final p in c.pantallas) ...[
                    const SizedBox(height: 8),
                    Aparecer(
                      orden: n + 1,
                      child: CardPantalla(
                        pantalla: p,
                        tono: c.tono,
                        dato: r == null ? null : datoDePantalla(p.ref, r),
                        onTap: () {
                          Navigator.pop(hoja);
                          context.go(rutaPantalla(p.ref));
                        },
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                const Padding(padding: EdgeInsets.fromLTRB(2, 0, 0, 10), child: Rotulo('Atajos')),
                Row(
                  children: [
                    Expanded(
                      child: TileAcceso(
                        icono: Icons.search_rounded,
                        tono: Paleta.verde,
                        titulo: 'Buscar',
                        detalle: 'Cualquier pantalla',
                        onTap: () {
                          Navigator.pop(hoja);
                          mostrarBuscadorPantallas(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TileAcceso(
                        icono: Paleta.oscuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        tono: Paleta.oscuro ? Paleta.oro : Paleta.pizarra,
                        titulo: Paleta.oscuro ? 'Modo día' : 'Modo noche',
                        detalle: 'Cambiar el aspecto',
                        onTap: () {
                          Navigator.pop(hoja);
                          context.read<ModoTema>().alternar();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
