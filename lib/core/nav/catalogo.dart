import 'package:flutter/material.dart';

import '../auth/sesion.dart';
import '../tema/paleta.dart';

/// Áreas y pantallas de COMEX. Para sumar una pantalla: agregala en [pantallasPorCategoria]
/// y en el `switch` de `ModuloPage`.
class Categoria {
  const Categoria({
    required this.clave,
    required this.titulo,
    required this.icono,
    required this._tono,
    required this.descripcion,
  });

  final String clave;
  final String titulo;
  final IconData icono;
  final Color Function() _tono;
  final String descripcion;

  /// Color del área (cambia con el modo claro / noche).
  Color get tono => _tono();

  /// Pantallas que puede abrir el usuario logueado.
  List<Pantalla> get pantallas =>
      [for (final p in pantallasPorCategoria[clave] ?? const <Pantalla>[]) if (p.permitidaPara(sesionVisible)) p];
}

class Pantalla {
  const Pantalla({
    required this.ref,
    required this.titulo,
    required this.icono,
    required this.descripcion,
    this.soloAdministrador = false,
  });

  final String ref;
  final String titulo;
  final IconData icono;
  final String descripcion;

  /// Sólo ADM / ADMIN (como el botón "Ir a Programa" de la versión Electron).
  final bool soloAdministrador;

  bool permitidaPara(Sesion? s) => !soloAdministrador || (s?.esAdministrador ?? false);
}

class UbicacionPantalla {
  const UbicacionPantalla(this.categoria, this.pantalla);
  final Categoria categoria;
  final Pantalla pantalla;
}

// Funciones (no colores) para que la lista siga siendo const y el color salga del modo actual.
Color _tonoAzul() => Paleta.azul;
Color _tonoVerde() => Paleta.verde;

const todasLasCategorias = <Categoria>[
  Categoria(
    clave: 'DESPACHOS',
    titulo: 'Despachos',
    icono: Icons.flight_takeoff_rounded,
    tono: _tonoAzul,
    descripcion: 'Programación de vuelos con el formato de la planilla de logística',
  ),
  Categoria(
    clave: 'PROGRAMA',
    titulo: 'Programa de trabajo',
    icono: Icons.event_note_rounded,
    tono: _tonoVerde,
    descripcion: 'Proyección de 11 días y programas de empaque por cliente',
  ),
];

const pantallasPorCategoria = <String, List<Pantalla>>{
  'DESPACHOS': [
    Pantalla(
      ref: 'VUELOS',
      titulo: 'Programación de despachos',
      icono: Icons.flight_rounded,
      descripcion: 'AWB, ruta, ETD / ETA, tarimas, status y CNNE por semana',
    ),
  ],
  'PROGRAMA': [
    Pantalla(
      ref: 'PROGRAMA',
      titulo: 'Programa de trabajo',
      icono: Icons.event_note_rounded,
      descripcion: 'Proyección por calibre y programas de empaque',
      soloAdministrador: true,
    ),
  ],
};

/// Usuario logueado (lo fija `SesionController`): menú, buscador e índice muestran sólo lo que puede abrir.
Sesion? sesionVisible;

/// Áreas con al menos una pantalla que el usuario logueado puede abrir.
List<Categoria> get categorias => [for (final c in todasLasCategorias) if (c.pantallas.isNotEmpty) c];

/// Índice inverso ref -> (categoría, pantalla) para migas y recientes (todas, sin filtrar).
final Map<String, UbicacionPantalla> indicePantallas = {
  for (final c in todasLasCategorias)
    for (final p in pantallasPorCategoria[c.clave] ?? const <Pantalla>[]) p.ref: UbicacionPantalla(c, p),
};

Categoria? categoriaPorClave(String clave) => categorias.where((c) => c.clave == clave).firstOrNull;

/// Una categoría con una sola pantalla abre directo esa pantalla.
String rutaCategoria(Categoria c) => c.pantallas.length == 1 ? rutaPantalla(c.pantallas.first.ref) : '/c/${c.clave}';

String rutaPantalla(String ref) => '/m/$ref';

/// Primera pantalla después del login (Vuelos, como en la versión Electron).
const rutaInicial = '/m/VUELOS';

/// Área a la que pertenece una ruta (/c/CLAVE o /m/REF); null en el inicio.
Categoria? categoriaDeRuta(String ruta) {
  if (ruta.startsWith('/c/')) return categoriaPorClave(ruta.substring(3));
  if (ruta.startsWith('/m/')) return indicePantallas[ruta.substring(3)]?.categoria;
  return null;
}

/// Texto sin mayúsculas ni tildes (para el buscador del menú).
String normalizar(String texto) {
  const desde = 'áéíóúüñ';
  const hasta = 'aeiouun';
  final minus = texto.toLowerCase();
  final sb = StringBuffer();
  for (final ch in minus.split('')) {
    final i = desde.indexOf(ch);
    sb.write(i >= 0 ? hasta[i] : ch);
  }
  return sb.toString();
}
