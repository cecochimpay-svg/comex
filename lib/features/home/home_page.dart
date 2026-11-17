import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/auth/sesion.dart';
import '../../core/auth/sesion_controller.dart';
import '../../core/nav/catalogo.dart';
import '../../core/preferencias.dart';
import '../../core/sync/servicio_sync.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/comunes.dart';
import '../shell/buscador_pantallas.dart';
import 'piezas_menu.dart';
import 'resumen_datos.dart';
import 'resumen_repo.dart';

/// Menú principal: portada con saludo y estado del equipo, una tarjeta por área con sus números
/// vivos y accesos directos, y los accesos rápidos (recientes + buscador).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with ResumenQueSeActualiza {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ServicioSync>().actualizarPendientes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionController>().actual;
    final prefs = context.watch<Preferencias>();
    final recientes = prefs.recientes;

    return PaginaContenido(
      child: ValueListenableBuilder<ResumenAreas?>(
        valueListenable: ResumenVivo.datos,
        builder: (context, resumen, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Aparecer(
              orden: 0,
              child: _Portada(sesion: sesion, ultimaSync: prefs.ultimaSincronizacion),
            ),
            const SizedBox(height: 28),
            const _TituloSeccion('¿A dónde vamos?', detalle: 'Tocá un área para ver sus pantallas'),
            const SizedBox(height: 12),
            GrillaLlena(
              anchoMinimo: 300,
              maxColumnas: 3,
              children: [
                for (final (i, c) in categorias.indexed)
                  Aparecer(
                    orden: i + 1,
                    child: _TarjetaArea(categoria: c, resumen: resumen),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            _TituloSeccion(
              'Accesos rápidos',
              detalle: recientes.isEmpty ? 'Las pantallas que abras van a aparecer acá' : 'Lo último que abriste',
            ),
            const SizedBox(height: 12),
            _AccesosRapidos(recientes: recientes, orden: categorias.length + 1),
          ],
        ),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto, {this.detalle});

  final String texto;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 10,
      runSpacing: 2,
      children: [
        Rotulo(texto),
        if (detalle != null) Text(detalle!, style: TextStyle(fontSize: 12, color: Paleta.tintaTenue)),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Portada: saludo, fecha, estado de sincronización y buscador
// -----------------------------------------------------------------------------
class _Portada extends StatelessWidget {
  const _Portada({required this.sesion, required this.ultimaSync});

  final Sesion? sesion;
  final DateTime? ultimaSync;

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<ServicioSync>();
    final pendientes = sync.pendientes;
    final offline = sesion?.offline ?? true;

    List<_ChipEstado> estado({bool vertical = false}) => [
      _ChipEstado(
        vertical: vertical,
        icono: pendientes > 0 ? Icons.cloud_upload_rounded : Icons.cloud_done_rounded,
        titulo: 'Pendientes de subir',
        valor: '$pendientes',
        detalle: pendientes > 0 ? 'Se suben al sincronizar' : 'Todo al día',
        alerta: pendientes > 0,
      ),
      _ChipEstado(
        icono: Icons.history_toggle_off_rounded,
        vertical: vertical,
        titulo: 'Última sincronización',
        valor: cuandoFue(ultimaSync),
        detalle: ultimaSync == null
            ? 'Sincronizá para traer los datos'
            : DateFormat("d 'de' MMMM, HH:mm", 'es').format(ultimaSync!),
      ),
      _ChipEstado(
        icono: offline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
        vertical: vertical,
        titulo: 'Modo de trabajo',
        valor: offline ? 'Local' : 'En línea',
        detalle: offline ? 'Datos guardados en este equipo' : 'Sesión de nube activa',
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final ancho = c.maxWidth >= 980;
        final angosto = c.maxWidth < 600;
        final saludo = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'COMEX · CECO S.A.',
              style: TextStyle(
                color: Paleta.trigo.withValues(alpha: 0.9),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              saludoDelMomento(sesion),
              style: TextStyle(
                color: Colors.white,
                fontSize: angosto ? 23 : 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [fechaLarga(), if (sesion != null && sesion!.rolEtiqueta.isNotEmpty) sesion!.rolEtiqueta].join(' · '),
              style: const TextStyle(color: Paleta.navTexto, fontSize: 13.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const _BuscadorPortada(),
          ],
        );

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F3D2A), Color(0xFF17563C), Color(0xFF226B4B)],
            ),
            boxShadow: Sombras.media,
          ),
          child: Stack(
            children: [
              // Marca de agua: las hojas del logo, grandes y apenas visibles.
              Positioned(
                right: -40,
                top: -60,
                child: Icon(Icons.grass_rounded, size: 260, color: Colors.white.withValues(alpha: 0.05)),
              ),
              Positioned(
                left: -40,
                bottom: -70,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Paleta.trigo.withValues(alpha: 0.05)),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  angosto ? 18 : 28,
                  angosto ? 18 : 24,
                  angosto ? 18 : 24,
                  angosto ? 20 : 26,
                ),
                child: ancho
                    ? Row(
                        children: [
                          Expanded(child: saludo),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: 380,
                            child: Column(
                              children: [
                                for (final (i, e) in estado().indexed) ...[if (i > 0) const SizedBox(height: 8), e],
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          saludo,
                          const SizedBox(height: 18),
                          if (angosto)
                            for (final (i, e) in estado().indexed) ...[if (i > 0) const SizedBox(height: 8), e]
                          else
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final (i, e) in estado(vertical: true).indexed) ...[
                                    if (i > 0) const SizedBox(width: 8),
                                    Expanded(child: e),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              const Positioned(left: 0, right: 0, bottom: 0, height: 3, child: ColoredBox(color: Paleta.trigo)),
            ],
          ),
        );
      },
    );
  }
}

/// Estado del equipo dentro de la portada: vidrio claro sobre el verde.
class _ChipEstado extends StatelessWidget {
  const _ChipEstado({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.detalle,
    this.alerta = false,
    this.vertical = false,
  });

  final IconData icono;
  final String titulo;
  final String valor;
  final String detalle;
  final bool alerta;

  /// En columna (título, número grande y detalle): para cuando van los tres en fila.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    const oro = Color(0xFFF2C46B);
    if (vertical) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 15, color: alerta ? oro : Paleta.menta),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    titulo.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Paleta.navTenue,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ContadorTexto(
              valor,
              maxLines: 1,
              style: TextStyle(
                color: alerta ? oro : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              detalle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Paleta.navTexto, fontSize: 11.5),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: alerta ? oro.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, size: 18, color: alerta ? oro : Paleta.menta),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Paleta.navTenue,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Paleta.navTexto, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ContadorTexto(
            valor,
            style: TextStyle(
              color: alerta ? oro : Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Caja "¿Qué querés abrir?" que abre el buscador de pantallas (Ctrl+K).
class _BuscadorPortada extends StatelessWidget {
  const _BuscadorPortada();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Presionable(
        etiqueta: 'Buscar pantalla',
        onTap: () => mostrarBuscadorPantallas(context),
        builder: (context, resaltado) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          padding: const EdgeInsets.only(left: 14, right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: resaltado ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: Colors.white.withValues(alpha: resaltado ? 0.4 : 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 19, color: Colors.white),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '¿Qué querés abrir?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Paleta.navTexto, fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: const Text(
                  'Ctrl K',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Áreas
// -----------------------------------------------------------------------------
class _TarjetaArea extends StatelessWidget {
  const _TarjetaArea({required this.categoria, required this.resumen});

  final Categoria categoria;
  final ResumenAreas? resumen;

  static const _maxAccesos = 5;

  @override
  Widget build(BuildContext context) {
    final c = categoria;
    final pantallas = c.pantallas;
    final r = resumen;
    final pendientes = r?.pendientesDe(c.clave) ?? 0;

    return TarjetaViva(
      tono: c.tono,
      marcaAgua: c.icono,
      tamanoMarca: 150,
      radio: 14,
      etiqueta: c.titulo,
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 16),
      onTap: () => context.go(rutaCategoria(c)),
      builder: (context, activa) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconoVivo(icono: c.icono, tono: c.tono, activa: activa, tamano: 46),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.titulo,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Paleta.tinta,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${pantallas.length} ${pantallas.length == 1 ? 'pantalla' : 'pantallas'}',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.tono),
                        ),
                        if (pendientes > 0) PildoraPendientes(cantidad: pendientes),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FlechaViva(tono: c.tono, activa: activa),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            c.descripcion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Paleta.tintaSuave, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Spacer(),
          if (r == null)
            const EsqueletoDato()
          else
            DatoArea(dato: datoPrincipal(c.clave, r), secundarios: datosSecundarios(c.clave, r)),
          const SizedBox(height: 14),
          Divider(height: 1, color: Paleta.bordeSuave),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in pantallas.take(_maxAccesos))
                AccesoPantalla(pantalla: p, tono: c.tono, onTap: () => context.go(rutaPantalla(p.ref))),
              if (pantallas.length > _maxAccesos)
                Padding(
                  padding: const EdgeInsets.only(left: 2, top: 5),
                  child: Text(
                    '+${pantallas.length - _maxAccesos} más',
                    style: TextStyle(fontSize: 11.5, color: Paleta.tintaTenue),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Accesos rápidos
// -----------------------------------------------------------------------------
class _AccesosRapidos extends StatelessWidget {
  const _AccesosRapidos({required this.recientes, required this.orden});

  final List<String> recientes;
  final int orden;

  @override
  Widget build(BuildContext context) {
    final ubicaciones = [for (final ref in recientes) ?indicePantallas[ref]];
    final tarjetas = <Widget>[
      for (final u in ubicaciones)
        TileAcceso(
          icono: u.pantalla.icono,
          tono: u.categoria.tono,
          titulo: u.pantalla.titulo,
          detalle: u.categoria.titulo,
          onTap: () => context.go(rutaPantalla(u.pantalla.ref)),
        ),
      TileAcceso(
        icono: Icons.search_rounded,
        tono: Paleta.verde,
        titulo: 'Buscar pantalla',
        detalle: 'Ctrl + K desde cualquier lugar',
        onTap: () => mostrarBuscadorPantallas(context),
      ),
    ];
    return GrillaLlena(
      anchoMinimo: 220,
      maxColumnas: tarjetas.length.clamp(1, 5),
      espacio: 12,
      cortasPrimero: false,
      children: [for (final (i, t) in tarjetas.indexed) Aparecer(orden: orden + i, child: t)],
    );
  }
}

// -----------------------------------------------------------------------------
// Textos
// -----------------------------------------------------------------------------

/// "Buenos días, Juan" según la hora.
String saludoDelMomento(Sesion? sesion, [DateTime? ahora]) {
  final hora = (ahora ?? DateTime.now()).hour;
  final saludo = hora >= 6 && hora < 13 ? 'Buenos días' : (hora >= 13 && hora < 20 ? 'Buenas tardes' : 'Buenas noches');
  final nombre = sesion?.primerNombre ?? '';
  return nombre.isEmpty ? saludo : '$saludo, $nombre';
}

/// "Martes 3 de noviembre".
String fechaLarga([DateTime? fecha]) {
  final texto = DateFormat("EEEE d 'de' MMMM", 'es').format(fecha ?? DateTime.now());
  return texto[0].toUpperCase() + texto.substring(1);
}

/// "Recién", "Hace 12 min", "Hoy 09:30", "Ayer 18:02", "Hace 3 días" o "Nunca".
String cuandoFue(DateTime? fecha, [DateTime? ahoraParam]) {
  if (fecha == null) return 'Nunca';
  final ahora = ahoraParam ?? DateTime.now();
  final diferencia = ahora.difference(fecha);
  if (diferencia.inMinutes < 1) return 'Recién';
  if (diferencia.inMinutes < 60) return 'Hace ${diferencia.inMinutes} min';
  final hora = DateFormat('HH:mm').format(fecha);
  final mismoDia = fecha.year == ahora.year && fecha.month == ahora.month && fecha.day == ahora.day;
  if (mismoDia) return 'Hoy $hora';
  final ayer = ahora.subtract(const Duration(days: 1));
  if (fecha.year == ayer.year && fecha.month == ayer.month && fecha.day == ayer.day) return 'Ayer $hora';
  return 'Hace ${diferencia.inDays} días';
}
