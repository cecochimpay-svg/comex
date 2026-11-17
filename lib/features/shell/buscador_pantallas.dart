import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/nav/catalogo.dart';
import '../../core/preferencias.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/animaciones.dart';
import '../home/resumen_datos.dart';
import '../home/resumen_repo.dart';

/// "Ir a…": busca una pantalla por nombre, área o descripción (sin tildes) y la abre. Atajo: Ctrl+K.
/// Sin texto muestra las recientes y después todas por área. Flechas para moverse y Enter para abrir.
Future<void> mostrarBuscadorPantallas(BuildContext context) async {
  final ruta = await showDialog<String>(context: context, builder: (_) => const _Buscador());
  if (ruta != null && context.mounted) context.go(ruta);
}

/// Resultados del buscador para [texto]: (título de grupo, pantallas). Pura, para los tests.
List<(String, List<UbicacionPantalla>)> resultadosBuscador(String texto, {List<String> recientes = const []}) {
  final q = normalizar(texto.trim());
  final grupos = <(String, List<UbicacionPantalla>)>[];
  if (q.isEmpty) {
    final r = [for (final ref in recientes) ?indicePantallas[ref]];
    if (r.isNotEmpty) grupos.add(('Recientes', r));
  }
  for (final c in categorias) {
    final lista = [
      for (final p in c.pantallas)
        if (q.isEmpty || normalizar('${p.titulo} ${c.titulo} ${p.descripcion}').contains(q)) UbicacionPantalla(c, p),
    ];
    if (lista.isNotEmpty) grupos.add((c.titulo, lista));
  }
  return grupos;
}

class _Buscador extends StatefulWidget {
  const _Buscador();

  @override
  State<_Buscador> createState() => _BuscadorState();
}

class _BuscadorState extends State<_Buscador> {
  String _texto = '';
  int _elegido = 0;
  final _llaves = <int, GlobalKey>{};
  late final List<String> _recientes;

  @override
  void initState() {
    super.initState();
    try {
      _recientes = context.read<Preferencias>().recientes;
    } catch (_) {
      _recientes = const [];
    }
  }

  List<(String, List<UbicacionPantalla>)> get _grupos => resultadosBuscador(_texto, recientes: _recientes);

  List<UbicacionPantalla> get _planos => [for (final (_, l) in _grupos) ...l];

  void _mover(int paso) {
    final n = _planos.length;
    if (n == 0) return;
    setState(() => _elegido = (_elegido + paso + n) % n);
    // Que la fila elegida quede a la vista.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _llaves[_elegido]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 120));
      }
    });
  }

  void _abrir(UbicacionPantalla u) => Navigator.pop(context, rutaPantalla(u.pantalla.ref));

  @override
  Widget build(BuildContext context) {
    final grupos = _grupos;
    final planos = _planos;
    if (_elegido >= planos.length) _elegido = 0;

    return Dialog(
      alignment: const Alignment(0, -0.55),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Paleta.borde),
      ),
      backgroundColor: Paleta.superficie,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _mover(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _mover(-1),
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 560),
          child: ValueListenableBuilder<ResumenAreas?>(
            valueListenable: ResumenVivo.datos,
            builder: (context, r, _) {
              var i = 0; // posición de cada fila en la lista plana (la que mueven las flechas)
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: Paleta.verde, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            style: TextStyle(fontSize: 16, color: Paleta.tinta, fontWeight: FontWeight.w500),
                            onChanged: (t) => setState(() {
                              _texto = t;
                              _elegido = 0;
                            }),
                            onSubmitted: (t) {
                              // Se recalcula con el texto final: Enter puede llegar antes de redibujar.
                              if (t != _texto) {
                                _texto = t;
                                _elegido = 0;
                              }
                              final lista = _planos;
                              if (lista.isNotEmpty) _abrir(lista[_elegido.clamp(0, lista.length - 1)]);
                            },
                            decoration: InputDecoration(
                              hintText: 'Ir a… (Acopio, Combustible, Órdenes…)',
                              hintStyle: TextStyle(color: Paleta.tintaTenue, fontWeight: FontWeight.w400),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                            ),
                          ),
                        ),
                        const _Tecla('Esc'),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Paleta.bordeSuave),
                  Flexible(
                    child: planos.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, size: 34, color: Paleta.tintaTenue),
                                const SizedBox(height: 8),
                                Text('No hay pantallas con ese nombre.', style: TextStyle(color: Paleta.tintaSuave)),
                              ],
                            ),
                          )
                        : ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            children: [
                              for (final (titulo, lista) in grupos) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                                  child: Text(
                                    titulo.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: Paleta.tintaTenue,
                                    ),
                                  ),
                                ),
                                for (final u in lista)
                                  () {
                                    final n = i++;
                                    return _FilaResultado(
                                      key: _llaves.putIfAbsent(n, GlobalKey.new),
                                      ubicacion: u,
                                      elegida: n == _elegido,
                                      dato: r == null ? null : datoDePantalla(u.pantalla.ref, r),
                                      alPasar: () => setState(() => _elegido = n),
                                      onTap: () => _abrir(u),
                                    );
                                  }(),
                              ],
                            ],
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
                    decoration: BoxDecoration(
                      color: Paleta.superficieSuave,
                      border: Border(top: BorderSide(color: Paleta.bordeSuave)),
                    ),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: const [
                        _Ayuda(teclas: ['↑', '↓'], texto: 'moverse'),
                        _Ayuda(teclas: ['Enter'], texto: 'abrir'),
                        _Ayuda(teclas: ['Esc'], texto: 'cerrar'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FilaResultado extends StatelessWidget {
  const _FilaResultado({
    super.key,
    required this.ubicacion,
    required this.elegida,
    required this.dato,
    required this.alPasar,
    required this.onTap,
  });

  final UbicacionPantalla ubicacion;
  final bool elegida;
  final String? dato;
  final VoidCallback alPasar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = ubicacion.pantalla;
    final c = ubicacion.categoria;
    return MouseRegion(
      onEnter: (_) => alPasar(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: sinAnimaciones(context) ? Duration.zero : const Duration(milliseconds: 100),
          padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
          decoration: BoxDecoration(
            color: elegida ? Paleta.suave(c.tono, 0.09) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: elegida ? c.tono.withValues(alpha: 0.35) : Colors.transparent),
          ),
          child: Row(
            children: [
              IconoVivo(icono: p.icono, tono: c.tono, activa: elegida, tamano: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Paleta.tinta),
                    ),
                    Text(
                      '${c.titulo} · ${p.descripcion}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Paleta.tintaSuave),
                    ),
                  ],
                ),
              ),
              if (dato != null && MediaQuery.sizeOf(context).width >= 600) ...[
                const SizedBox(width: 10),
                Text(
                  dato!,
                  style: TextStyle(fontSize: 11.5, color: c.tono, fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(width: 8),
              Icon(
                elegida ? Icons.keyboard_return_rounded : Icons.arrow_forward_rounded,
                size: 16,
                color: elegida ? c.tono : Paleta.tintaTenue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tecla extends StatelessWidget {
  const _Tecla(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Paleta.superficie,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: Paleta.borde),
      boxShadow: [BoxShadow(color: Paleta.borde, offset: const Offset(0, 1))],
    ),
    child: Text(
      texto,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Paleta.tintaSuave),
    ),
  );
}

class _Ayuda extends StatelessWidget {
  const _Ayuda({required this.teclas, required this.texto});

  final List<String> teclas;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final t in teclas) ...[_Tecla(t), const SizedBox(width: 3)],
      const SizedBox(width: 3),
      Text(texto, style: TextStyle(fontSize: 11.5, color: Paleta.tintaTenue)),
    ],
  );
}
