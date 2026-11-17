import 'package:flutter/material.dart';

import '../core/db/filas.dart';
import '../core/tema/paleta.dart';
import 'animaciones.dart';

// Resaltado de las filas que cambiaron al guardar: la pantalla toma las firmas de sus filas antes de
// recargar ([firmasDe]), las compara con las nuevas ([CambiosRecientes.comparar]) y las filas con
// `clave` cambiada se iluminan en verde suave y se apagan solas ([Resaltable]).
//
// Uso en una pantalla:
//   final _cambios = CambiosRecientes();
//   Map<Object, int> _firmas() => firmasDe(_datos?.lista ?? const [], (x) => x.f, prefijo: 'ing');
//   // en _trasGuardar: final antes = _firmas(); await _cargar(); _cambios.comparar(antes, _firmas());
//   // en build: ResaltarCambios(cambios: _cambios, child: PaginaListado(...))
//   // en la fila: ContenedorFila(clave: claveFila('ing', f), ...) o Resaltable(clave: ..., child: tarjeta)

/// Columnas que cambian sin que el usuario toque la fila (la sincronización las reescribe).
const _columnasIgnoradas = {'sincronizado'};

/// Más filas cambiadas que esto no es un guardado del usuario (p. ej. una bajada completa): no se marca nada.
const maximoResaltadas = 30;

/// Clave de una fila para el resaltado: prefijo de la tabla + id (+ reg_local, si la tabla lo usa).
String claveFila(String prefijo, Fila f) {
  final reg = txt(f['reg_local']);
  return reg.isEmpty ? '$prefijo:${txt(f['id'])}' : '$prefijo:${txt(f['id'])}:$reg';
}

/// Firma de contenido de cada fila (clave -> hash de sus columnas, sin [_columnasIgnoradas]).
Map<Object, int> firmasDe<T>(Iterable<T> items, Fila Function(T) fila, {required String prefijo}) => {
  for (final x in items)
    claveFila(prefijo, fila(x)): Object.hashAll([
      for (final e in fila(x).entries)
        if (!_columnasIgnoradas.contains(e.key)) Object.hash(e.key, e.value),
    ]),
};

/// Claves nuevas o con contenido distinto (las borradas no cuentan: ya no están en pantalla).
Set<Object> clavesCambiadas(Map<Object, int> antes, Map<Object, int> despues) => {
  for (final e in despues.entries)
    if (antes[e.key] != e.value) e.key,
};

/// Marcas de la pantalla: clave -> momento en que cambió. Las filas que se arman tarde (lista perezosa)
/// retoman la animación donde va, así al desplazarse no se vuelven a encender.
class CambiosRecientes {
  static const duracion = Duration(milliseconds: 1800);

  final _marcas = <Object, DateTime>{};

  void comparar(Map<Object, int> antes, Map<Object, int> despues) {
    final cambiadas = clavesCambiadas(antes, despues);
    if (cambiadas.isEmpty || cambiadas.length > maximoResaltadas) return;
    final ahora = DateTime.now();
    _marcas.removeWhere((_, t) => ahora.difference(t) > duracion);
    for (final c in cambiadas) {
      _marcas[c] = ahora;
    }
  }

  /// Avance de la animación (0 = recién cambiada, 1 = apagada); null si la fila no cambió.
  double? avance(Object clave) {
    final t = _marcas[clave];
    if (t == null) return null;
    final v = DateTime.now().difference(t).inMilliseconds / duracion.inMilliseconds;
    return v >= 1 ? null : v;
  }
}

/// Pone las marcas de la pantalla al alcance de sus filas.
class ResaltarCambios extends InheritedWidget {
  const ResaltarCambios({super.key, required this.cambios, required super.child});

  final CambiosRecientes cambios;

  static CambiosRecientes? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ResaltarCambios>()?.cambios;

  @override
  bool updateShouldNotify(ResaltarCambios old) => old.cambios != cambios;
}

/// Envuelve una fila o tarjeta: si su [clave] cambió, se pinta encima un verde suave con borde que se apaga
/// (sostiene un instante y se desvanece). Sin [ResaltarCambios] arriba o con la clave en null, no hace nada.
/// En tarjetas con margen, pasarlo en [margen] (y sacarlo del `Container`) para no pintar el hueco.
class Resaltable extends StatefulWidget {
  const Resaltable({super.key, required this.clave, required this.child, this.radio = BorderRadius.zero, this.margen});

  final Object? clave;
  final Widget child;
  final BorderRadius radio;
  final EdgeInsetsGeometry? margen;

  @override
  State<Resaltable> createState() => _ResaltableState();
}

class _ResaltableState extends State<Resaltable> with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _revisar();
  }

  @override
  void didUpdateWidget(Resaltable old) {
    super.didUpdateWidget(old);
    _revisar();
  }

  /// Arranca (o retoma) la animación si la clave está marcada y no hay una en curso.
  void _revisar() {
    final clave = widget.clave;
    if (clave == null || sinAnimaciones(context)) return;
    final desde = ResaltarCambios.of(context)?.avance(clave);
    if (desde == null || (_ctrl?.isAnimating ?? false)) return;
    final c = _ctrl ??= AnimationController(vsync: this, duration: CambiosRecientes.duracion);
    if (!c.isAnimating) c.addListener(_redibujar);
    c.forward(from: desde);
  }

  void _redibujar() {
    if (!mounted) return;
    setState(() {});
    if (_ctrl!.isCompleted) _ctrl!.removeListener(_redibujar);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    final m = widget.margen;
    if (c == null || !c.isAnimating) return m == null ? widget.child : Padding(padding: m, child: widget.child);
    // Sostiene el primer 25 % y después se apaga suave.
    final fuerza = 1 - Curves.easeInCubic.transform(((c.value - 0.25) / 0.75).clamp(0.0, 1.0));
    final pintada = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        color: Paleta.verde.withValues(alpha: 0.13 * fuerza),
        borderRadius: widget.radio,
        border: Border.all(color: Paleta.verde.withValues(alpha: 0.55 * fuerza), width: 1.2),
      ),
      child: widget.child,
    );
    return m == null ? pintada : Padding(padding: m, child: pintada);
  }
}
