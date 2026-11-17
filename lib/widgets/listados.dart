import 'dart:math';

import 'package:flutter/material.dart';

import '../core/tema/paleta.dart';
import 'animaciones.dart';
import 'comunes.dart';
import 'resaltar.dart';

/// Piezas compartidas por las pantallas de listado (estilo oficina): tarjetas con borde fino,
/// indicadores, filtros, pastillas, tablas con hover de fila y botones de fila.

/// Tarjeta blanca (o la superficie de noche) con borde fino. El radio se limita a 10 (look compacto).
BoxDecoration decoTarjeta({double radio = 10}) => BoxDecoration(
  color: Paleta.superficie,
  borderRadius: BorderRadius.circular(min(radio, 10)),
  border: Border.all(color: Paleta.borde),
  boxShadow: Sombras.suave,
);

const cifrasTabulares = [FontFeature.tabularFigures()];

/// Indicador (como `Kpi` de oficina): ícono del tono en un cuadradito, rótulo chico, valor y detalle.
class DatoResumen extends StatelessWidget {
  const DatoResumen({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.detalle,
    required this.color,
    required this.icono,
    this.detalleColor,
  });

  final String rotulo;
  final String valor;
  final String detalle;
  final Color color;
  final IconData icono;
  final Color? detalleColor;

  @override
  Widget build(BuildContext context) {
    final tono = color == Paleta.tinta ? Paleta.pizarra : color;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Paleta.superficieSuave,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Paleta.bordeSuave),
      ),
      child: Row(
        children: [
          IconoTono(icono: icono, tono: tono, tamano: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rotulo.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Paleta.tintaTenue,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.25,
                    fontFeatures: cifrasTabulares,
                  ),
                ),
                Text(
                  detalle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: detalleColor ?? Paleta.tintaSuave,
                    fontWeight: FontWeight.w500,
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

/// Desplegable de filtro compacto. Con un valor distinto del primero queda marcado en verde suave.
class SelectorFiltro<T> extends StatelessWidget {
  const SelectorFiltro({super.key, required this.valor, required this.opciones, required this.alCambiar});

  final T valor;
  final List<(T, String)> opciones;
  final ValueChanged<T> alCambiar;

  @override
  Widget build(BuildContext context) {
    // Si el valor elegido ya no existe (p. ej. tras borrar), se muestra la primera opción.
    final actual = opciones.any((o) => o.$1 == valor) ? valor : opciones.first.$1;
    final activo = actual != opciones.first.$1;
    return Container(
      height: 38,
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: activo ? Paleta.verdeSuave : Paleta.superficie,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: activo ? Paleta.verdeLinea : Paleta.borde),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: actual,
          isExpanded: true,
          borderRadius: BorderRadius.circular(8),
          dropdownColor: Paleta.superficie,
          icon: Icon(Icons.expand_more_rounded, size: 18, color: Paleta.tintaSuave),
          style: TextStyle(
            fontSize: 13,
            fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
            color: activo ? Paleta.verdeTitulo : Paleta.tinta,
          ),
          items: [
            for (final (v, t) in opciones)
              DropdownMenuItem(
                value: v,
                child: Text(t, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => alCambiar(v as T),
        ),
      ),
    );
  }
}

/// Etiqueta de estado (como `EtiquetaEstado` de oficina): fondo suave del color y borde apenas marcado.
class Pastilla extends StatelessWidget {
  const Pastilla({super.key, required this.texto, required this.color, this.icono});

  final String texto;
  final Color color;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Paleta.suave(color, 0.11),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icon(icono, size: 11, color: color), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class BotonIconoFila extends StatelessWidget {
  const BotonIconoFila({super.key, required this.icono, required this.ayuda, this._color, this.onTap});

  final IconData icono;
  final String ayuda;
  final Color? _color;
  Color get color => _color ?? Paleta.tintaSuave;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: ayuda,
      onPressed: onTap,
      icon: Icon(icono, size: 17),
      color: color,
      disabledColor: Paleta.tintaTenue.withValues(alpha: 0.5),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(30),
        minimumSize: const Size.square(30),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        hoverColor: Paleta.suave(color, 0.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Ícono en un círculo con halo (estados vacío y de error, como `VacioOficina`).
class _Halo extends StatelessWidget {
  const _Halo({required this.icono, required this.tono});

  final IconData icono;
  final Color tono;

  @override
  Widget build(BuildContext context) => Container(
    width: 72,
    height: 72,
    alignment: Alignment.center,
    decoration: BoxDecoration(shape: BoxShape.circle, color: tono.withValues(alpha: 0.06)),
    child: Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Paleta.superficie, Paleta.suave(tono, 0.12)],
        ),
        border: Border.all(color: tono.withValues(alpha: 0.2)),
      ),
      child: Icon(icono, size: 23, color: tono),
    ),
  );
}

class ErrorCarga extends StatelessWidget {
  const ErrorCarga({
    super.key,
    required this.error,
    required this.reintentar,
    this.titulo = 'No se pudieron cargar los datos locales',
  });

  final Object error;
  final String titulo;
  final VoidCallback reintentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: decoTarjeta(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _Halo(icono: Icons.error_outline_rounded, tono: Paleta.peligro),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Paleta.peligro),
          ),
          const SizedBox(height: 4),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: TextStyle(color: Paleta.tintaSuave, fontSize: 12),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: reintentar,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

/// Color estable por nombre (depósitos, rubros, orígenes): mismo cálculo que AgroUI.colorDe.
/// De noche usa versiones más claras del mismo tono (se leen sobre el fondo oscuro).
Color colorDeNombre(String? nombre) {
  const claros = [
    Color(0xFF1E6B4C),
    Color(0xFF0A66C2),
    Color(0xFF8B4FD9),
    Color(0xFFC77700),
    Color(0xFF00838F),
    Color(0xFFB23A48),
  ];
  const noche = [
    Color(0xFF4CC28A),
    Color(0xFF6BAEF2),
    Color(0xFFB5A6E3),
    Color(0xFFE8AD4C),
    Color(0xFF4DC3CE),
    Color(0xFFF07A8A),
  ];
  final t = (nombre == null || nombre.trim().isEmpty ? 'X' : nombre)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toUpperCase();
  var h = 0;
  for (final c in t.codeUnits) {
    h = (c + ((h << 5) - h)).toSigned(32); // aritmética de 32 bits, como en JS
  }
  return (Paleta.oscuro ? noche : claros)[h.abs() % claros.length];
}

/// Mensaje centrado cuando un listado no tiene filas.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.mensaje, this.icono = Icons.inbox_rounded});

  final String mensaje;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: decoTarjeta(),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          _Halo(icono: icono, tono: Paleta.verde),
          const SizedBox(height: 12),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: TextStyle(color: Paleta.tintaSuave, fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Nube verde si el registro ya subió; ámbar si está pendiente de sincronizar.
class IndicadorSync extends StatelessWidget {
  const IndicadorSync({super.key, required this.sincronizado});

  final Object? sincronizado;

  @override
  Widget build(BuildContext context) {
    final ok = '$sincronizado' == '1';
    return Tooltip(
      message: ok ? 'Sincronizado' : 'Pendiente de subir',
      child: Icon(
        ok ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
        size: 15,
        color: ok ? Paleta.exito : Paleta.oro,
      ),
    );
  }
}

/// Página de listado largo: cabecera (encabezado, indicadores, filtros) y filas perezosas, así miles de
/// registros no traban la pantalla. Mismos márgenes y ancho máximo que [PaginaContenido].
class PaginaListado extends StatelessWidget {
  const PaginaListado({
    super.key,
    required this.cabecera,
    required this.cantidad,
    required this.fila,
    this.vacio,
    this.pie,
    this.anchoMaximo = 1320,
  });

  final List<Widget> cabecera;
  final int cantidad;
  final IndexedWidgetBuilder fila;
  final Widget? vacio;
  final Widget? pie;
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final angosta = c.maxWidth < 600;
        final lateral = angosta ? 12.0 : 24.0;
        final h = lateral + max(0.0, (c.maxWidth - 2 * lateral - anchoMaximo) / 2);
        EdgeInsets lados([double arriba = 0]) => EdgeInsets.fromLTRB(h, arriba, h, 0);
        return FundidoEntrada(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: lados(angosta ? 12 : 18),
                sliver: SliverList.list(children: cabecera),
              ),
              SliverPadding(
                padding: lados(),
                sliver: cantidad == 0 && vacio != null
                    ? SliverToBoxAdapter(child: vacio)
                    : SliverList.builder(itemCount: cantidad, itemBuilder: fila),
              ),
              if (pie != null)
                SliverPadding(
                  padding: lados(),
                  sliver: SliverToBoxAdapter(child: pie),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 36)),
            ],
          ),
        );
      },
    );
  }
}

/// Fila de una tabla armada con flex: [columnas] = (flex, celda, alineada a la derecha).
/// Las celdas de la tabla y el encabezado usan la misma definición, así quedan alineadas.
class FilaTabla extends StatelessWidget {
  const FilaTabla({super.key, required this.celdas, this.acciones, this.anchoAcciones = 0});

  final List<(int, Widget, bool)> celdas;
  final Widget? acciones;
  final double anchoAcciones;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (flex, celda, der) in celdas)
        Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(alignment: der ? Alignment.centerRight : Alignment.centerLeft, child: celda),
          ),
        ),
      if (anchoAcciones > 0) SizedBox(width: anchoAcciones, child: acciones),
    ],
  );
}

/// Bordes de una tabla partida en filas (encabezado arriba redondeado, filas, pie abajo redondeado).
/// El encabezado ([primera]) va en gris verdoso suave, como el de `TablaOficina`.
BoxDecoration decoFilaTabla({bool primera = false, bool ultima = false, Color? color}) => BoxDecoration(
  color: color ?? (primera ? Paleta.superficieSuave : Paleta.superficie),
  border: Border(
    left: BorderSide(color: Paleta.borde),
    right: BorderSide(color: Paleta.borde),
    // Mismo color en todos los lados (Flutter lo exige con esquinas redondeadas); el de arriba, más fino.
    top: BorderSide(color: Paleta.borde, width: primera ? 1 : 0.6),
    bottom: ultima ? BorderSide(color: Paleta.borde) : BorderSide.none,
  ),
  borderRadius: BorderRadius.vertical(
    top: primera ? const Radius.circular(10) : Radius.zero,
    bottom: ultima ? const Radius.circular(10) : Radius.zero,
  ),
);

/// Contenedor de una fila de tabla con hover (fondo verde muy suave al pasar el mouse) y fila
/// marcada ([seleccionada]: fondo verde claro con una barrita a la izquierda), como `TablaOficina`.
/// Mismos parámetros que el `Container` que reemplaza; la decoración es la de [decoFilaTabla].
/// Con [clave] (ver `claveFila`), se ilumina un momento si la fila cambió al guardar ([Resaltable]).
class ContenedorFila extends StatefulWidget {
  const ContenedorFila({
    super.key,
    required this.decoration,
    this.child,
    this.padding,
    this.margin,
    this.constraints,
    this.alignment,
    this.height,
    this.seleccionada = false,
    this.clave,
  });

  final BoxDecoration decoration;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxConstraints? constraints;
  final AlignmentGeometry? alignment;
  final double? height;
  final bool seleccionada;
  final Object? clave;

  @override
  State<ContenedorFila> createState() => _ContenedorFilaState();
}

class _ContenedorFilaState extends State<ContenedorFila> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.decoration;
    // Las filas con color propio (anuladas, marcadas) lo conservan; el hover pinta sólo las comunes.
    final comun = d.color == Paleta.superficie;
    final color = widget.seleccionada ? Paleta.filaSel : (_hover && comun ? Paleta.filaHover : d.color);
    final fila = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        height: widget.height,
        margin: widget.margin,
        constraints: widget.constraints,
        alignment: widget.alignment,
        padding: widget.padding,
        decoration: d.copyWith(color: color),
        foregroundDecoration: widget.seleccionada
            ? BoxDecoration(
                border: Border(left: BorderSide(color: Paleta.verde, width: 3)),
              )
            : null,
        child: widget.child,
      ),
    );
    return widget.clave == null ? fila : Resaltable(clave: widget.clave, child: fila);
  }
}

/// Texto de encabezado de tabla (mayúsculas chicas en gris, sobre el encabezado suave).
Widget textoEncabezado(String t) => Text(
  t.toUpperCase(),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(color: Paleta.tintaSuave, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5),
);

/// Esqueleto de carga de una pantalla (en lugar de la ruedita): indicadores, barra de filtros y filas
/// fantasma del mismo alto que las reales; en celular, tarjetas. Aparece con un fundido.
class CargandoListado extends StatelessWidget {
  const CargandoListado({super.key, this.filas = 8, this.indicadores = 4});

  final int filas;
  final int indicadores;

  @override
  Widget build(BuildContext context) {
    final angosta = MediaQuery.sizeOf(context).width < 1000;
    // Anchos que varían por fila y columna, para que no parezca una grilla pareja.
    double ancho(int fila, int col) => 0.45 + ((fila * 7 + col * 13) % 10) / 20;
    Widget indicador() => Container(
      height: 64,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Paleta.superficieSuave,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Paleta.bordeSuave),
      ),
      child: const Row(
        children: [
          Hueso(ancho: 36, alto: 36, radio: 8),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Hueso(ancho: 70, alto: 8), SizedBox(height: 6), Hueso(ancho: 110, alto: 14)],
            ),
          ),
        ],
      ),
    );
    final nIndicadores = angosta ? min(2, indicadores) : indicadores;
    Widget hueso(int f, int col, {double alto = 10, double factor = 1, bool derecha = false}) => LayoutBuilder(
      builder: (context, c) => Align(
        alignment: derecha ? Alignment.centerRight : Alignment.centerLeft,
        child: Hueso(ancho: c.maxWidth * ancho(f, col) * factor, alto: alto),
      ),
    );
    return Semantics(
      label: 'Cargando',
      child: FundidoEntrada(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (nIndicadores > 0) ...[
              Row(
                children: [
                  for (var i = 0; i < nIndicadores; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: indicador()),
                  ],
                ],
              ),
              const SizedBox(height: 14),
            ],
            const Row(
              children: [
                Flexible(child: Hueso(ancho: 260, alto: 36, radio: 10)),
                SizedBox(width: 10),
                Flexible(child: Hueso(ancho: 160, alto: 36, radio: 8)),
              ],
            ),
            const SizedBox(height: 14),
            if (angosta)
              for (var f = 0; f < filas ~/ 2; f++)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: decoTarjeta(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      hueso(f, 0, alto: 13),
                      const SizedBox(height: 8),
                      hueso(f, 1, factor: 0.7),
                      const SizedBox(height: 6),
                      hueso(f, 2, factor: 0.5),
                    ],
                  ),
                )
            else ...[
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: decoFilaTabla(primera: true),
                child: Row(
                  children: [
                    for (var col = 0; col < 5; col++)
                      Expanded(
                        flex: col == 1 ? 3 : 2,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Align(alignment: Alignment.centerLeft, child: Hueso(ancho: 56, alto: 8)),
                        ),
                      ),
                  ],
                ),
              ),
              for (var f = 0; f < filas; f++)
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: decoFilaTabla(ultima: f == filas - 1),
                  child: Row(
                    children: [
                      for (var col = 0; col < 5; col++)
                        Expanded(
                          flex: col == 1 ? 3 : 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: hueso(f, col, alto: col == 1 ? 12 : 10, derecha: col == 4),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
