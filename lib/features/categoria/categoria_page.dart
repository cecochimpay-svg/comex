import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/nav/catalogo.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/comunes.dart';
import '../home/piezas_menu.dart';
import '../home/resumen_datos.dart';
import '../home/resumen_repo.dart';

/// Panel de un área: cabecera en el color del área con sus números y una tarjeta por pantalla, cada una
/// con su dato vivo.
class CategoriaPage extends StatefulWidget {
  const CategoriaPage({super.key, required this.clave});

  final String clave;

  @override
  State<CategoriaPage> createState() => _CategoriaPageState();
}

class _CategoriaPageState extends State<CategoriaPage> with ResumenQueSeActualiza {
  @override
  Widget build(BuildContext context) {
    final c = categoriaPorClave(widget.clave);
    if (c == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
      return const SizedBox.shrink();
    }

    return PaginaContenido(
      child: ValueListenableBuilder<ResumenAreas?>(
        valueListenable: ResumenVivo.datos,
        builder: (context, r, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Migas(categoria: c),
            const SizedBox(height: 10),
            Aparecer(
              orden: 0,
              child: CabeceraArea(categoria: c, resumen: r),
            ),
            const SizedBox(height: 26),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 10,
              children: [
                const Rotulo('Pantallas'),
                Text('${c.pantallas.length} en ${c.titulo}', style: TextStyle(fontSize: 12, color: Paleta.tintaTenue)),
              ],
            ),
            const SizedBox(height: 12),
            GrillaLlena(
              anchoMinimo: 250,
              maxColumnas: 4,
              children: [
                for (final (i, p) in c.pantallas.indexed)
                  Aparecer(
                    orden: i + 1,
                    child: _TarjetaPantalla(
                      pantalla: p,
                      tono: c.tono,
                      dato: r == null ? null : datoDePantalla(p.ref, r),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Inicio › Producción".
class _Migas extends StatelessWidget {
  const _Migas({required this.categoria});

  final Categoria categoria;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('Inicio'),
          style: TextButton.styleFrom(
            foregroundColor: Paleta.tintaSuave,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
          ),
        ),
        Icon(Icons.chevron_right_rounded, size: 16, color: Paleta.tintaTenue),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            categoria.titulo,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Paleta.tinta),
          ),
        ),
      ],
    );
  }
}

/// Color de fondo de la cabecera de un área: el tono del área llevado a oscuro (se lee texto blanco en los
/// dos modos; de noche, los tonos son claros y hay que bajarlos más).
/// Degradé de la cabecera por área: los tonos de marca (iguales en los dos modos, como la barra de arriba).
const _cabeceras = <String, (Color, Color)>{
  'INSUMOS': (Color(0xFF0F3D2A), Color(0xFF1E6B4C)),
  'PRODUCCION': (Color(0xFF8A5409), Color(0xFFC27C0E)),
  'LABORES': (Color(0xFF1B4699), Color(0xFF2F6FDE)),
  'PARAMETROS': (Color(0xFF262D36), Color(0xFF4B5563)),
  'REPORTES': (Color(0xFF7E3A1C), Color(0xFFB5562E)),
};

(Color, Color) coloresCabeceraArea(Categoria c) => _cabeceras[c.clave] ?? fondoCabeceraArea(c.tono);

(Color, Color) fondoCabeceraArea(Color tono) {
  const noche = Color(0xFF0C1410);
  final a = Color.lerp(tono, noche, Paleta.oscuro ? 0.62 : 0.38)!;
  final b = Color.lerp(tono, noche, Paleta.oscuro ? 0.45 : 0.12)!;
  return (a, b);
}

/// Cabecera de un área: ícono, título, descripción y los números del área en vidrio claro.
class CabeceraArea extends StatelessWidget {
  const CabeceraArea({super.key, required this.categoria, required this.resumen});

  final Categoria categoria;
  final ResumenAreas? resumen;

  @override
  Widget build(BuildContext context) {
    final c = categoria;
    final r = resumen;
    final (a, b) = coloresCabeceraArea(c);
    final pendientes = r?.pendientesDe(c.clave) ?? 0;

    return LayoutBuilder(
      builder: (context, box) {
        final angosto = box.maxWidth < 600;
        final ancho = box.maxWidth >= 900;
        final titulo = Row(
          children: [
            Container(
              width: angosto ? 46 : 56,
              height: angosto ? 46 : 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Icon(c.icono, color: Colors.white, size: angosto ? 24 : 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.titulo,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: angosto ? 22 : 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(c.descripcion, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5)),
                ],
              ),
            ),
          ],
        );

        final numeros = <Widget>[
          if (r == null)
            for (var i = 0; i < 2; i++)
              Container(
                width: 150,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
              )
          else ...[
            _NumeroVidrio(dato: datoPrincipal(c.clave, r)),
            for (final s in datosSecundarios(c.clave, r).take(2)) _NumeroVidrio(dato: s),
            if (pendientes > 0)
              _NumeroVidrio(dato: DatoVivo('$pendientes', 'sin subir a la nube'), icono: Icons.cloud_upload_rounded),
          ],
        ];

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]),
            boxShadow: Sombras.media,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -36,
                top: -46,
                child: Icon(c.icono, size: 210, color: Colors.white.withValues(alpha: 0.07)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  angosto ? 18 : 26,
                  angosto ? 18 : 24,
                  angosto ? 18 : 24,
                  angosto ? 20 : 24,
                ),
                child: ancho
                    ? Row(
                        children: [
                          Expanded(flex: 4, child: titulo),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: numeros),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          titulo,
                          const SizedBox(height: 16),
                          Wrap(spacing: 8, runSpacing: 8, children: numeros),
                        ],
                      ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 3,
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.28)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Número sobre la cabecera del área (vidrio claro).
class _NumeroVidrio extends StatelessWidget {
  const _NumeroVidrio({required this.dato, this.icono});

  final DatoVivo dato;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final d = dato;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 16, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icon(icono, size: 18, color: Colors.white), const SizedBox(width: 8)],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ContadorTexto(
                d.valor,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
              Text(d.leyenda, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaPantalla extends StatelessWidget {
  const _TarjetaPantalla({required this.pantalla, required this.tono, required this.dato});

  final Pantalla pantalla;
  final Color tono;

  /// Dato vivo de la pantalla; null mientras se lee la base.
  final String? dato;

  @override
  Widget build(BuildContext context) {
    return TarjetaViva(
      tono: tono,
      marcaAgua: pantalla.icono,
      tamanoMarca: 110,
      radio: 14,
      etiqueta: pantalla.titulo,
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
      onTap: () => context.go(rutaPantalla(pantalla.ref)),
      builder: (context, activa) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconoVivo(icono: pantalla.icono, tono: tono, activa: activa, tamano: 44),
              const Spacer(),
              FlechaViva(tono: tono, activa: activa, tamano: 28),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            pantalla.titulo,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: Paleta.tinta),
          ),
          const SizedBox(height: 3),
          Text(
            pantalla.descripcion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: Paleta.tintaSuave, height: 1.4),
          ),
          const SizedBox(height: 14),
          const Spacer(),
          if (dato == null) const Hueso(ancho: 140, alto: 22, radio: 11) else DatoPastilla(texto: dato!, tono: tono),
        ],
      ),
    );
  }
}

/// Dato vivo de una pantalla en una pastilla del color del área.
class DatoPastilla extends StatelessWidget {
  const DatoPastilla({super.key, required this.texto, required this.tono});

  final String texto;
  final Color tono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(color: Paleta.suave(tono, 0.1), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: tono, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Paleta.tinta),
            ),
          ),
        ],
      ),
    );
  }
}
