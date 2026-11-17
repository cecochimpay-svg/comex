import 'package:flutter/material.dart';

/// Paleta "oficina": fondo gris verdoso claro, superficies blancas, bordes finos y el verde agro
/// sólo como acento. Tiene modo claro y modo noche: cada color es un getter que lee [Paleta.oscuro]
/// (lo cambia `ModoTema`, que además redibuja toda la app). Lo que es de marca y se ve igual en los
/// dos modos (barra de arriba, bosque, trigo) queda `const`.
abstract final class Paleta {
  /// Modo noche. No cambiarlo a mano: usar `ModoTema` (guarda la preferencia y redibuja).
  static bool oscuro = false;

  static Color _c(int claro, int noche) => Color(oscuro ? noche : claro);

  /// Color propio de una pantalla con su versión de noche.
  static Color dual(int claro, int noche) => _c(claro, noche);

  // Superficies
  static Color get fondo => _c(0xFFF3F5F4, 0xFF0E1411);
  static Color get superficie => _c(0xFFFFFFFF, 0xFF161D19);
  static Color get superficieSuave => _c(0xFFF8FAF9, 0xFF1B231F);

  /// Campo de sólo lectura / fondo hundido (un escalón más que [superficieSuave]).
  static Color get superficieHundida => _c(0xFFEFF2F0, 0xFF111814);
  static Color get borde => _c(0xFFD3DAD5, 0xFF2B3631);
  static Color get bordeSuave => _c(0xFFE3E8E4, 0xFF222C27);
  static Color get bordeFuerte => _c(0xFFC2CBC5, 0xFF3A4740);

  // Texto
  static Color get tinta => _c(0xFF18201B, 0xFFE4EAE6);
  static Color get tintaSuave => _c(0xFF5A665E, 0xFFA3B0A8);
  static Color get tintaTenue => _c(0xFF8A958D, 0xFF75827A);

  // Marca
  static Color get verde => _c(0xFF1E6B4C, 0xFF2F9467);

  /// Verde oscuro para fondos con texto blanco (cabeceras de tabla, totales, botón principal).
  static Color get verdeOscuro => _c(0xFF123F2C, 0xFF1F4D39);

  /// Verde para títulos y textos destacados: muy oscuro de día, verde claro de noche.
  static Color get verdeTitulo => _c(0xFF0F3D2A, 0xFFA8DCC0);
  static Color get verdeClaro => _c(0xFF34A06E, 0xFF4CC28A);

  /// Verde muy suave para fondos de lo elegido / activo, y su línea.
  static Color get verdeSuave => _c(0x171E6B4C, 0x2E4CC28A);
  static Color get verdeLinea => _c(0x591E6B4C, 0x704CC28A);
  static const bosque = Color(0xFF0E2A1E);
  static const bosqueProfundo = Color(0xFF09170F);
  static const menta = Color(0xFF9FEAC2);
  static Color get oro => _c(0xFFC27C0E, 0xFFE8AD4C);
  static const trigo = Color(0xFFF2D98A);

  // Acentos por área
  static Color get azul => _c(0xFF2F6FDE, 0xFF6BAEF2);
  static Color get pizarra => _c(0xFF4B5563, 0xFF9AA6B5);
  static Color get terracota => _c(0xFFB5562E, 0xFFE58C64);
  static Color get violeta => _c(0xFF6B4FC0, 0xFFB5A6E3);

  // Estados
  static Color get exito => _c(0xFF1F9D55, 0xFF6CC070);
  static Color get peligro => _c(0xFFC62828, 0xFFF07470);

  // Tablas (como `TablaOficina` del panel de oficina)
  static Color get filaHover => _c(0xFFF4F9F5, 0xFF1C2621);
  static Color get filaSel => _c(0xFFDCEFE2, 0xFF1D3A2C);

  // Barra superior (texto sobre bosque, igual en los dos modos)
  static const navTexto = Color(0xFFBBD0C2);
  static const navTenue = Color(0xFF7F9C8C);

  /// Verde de marca para fondos (barra de arriba, tooltips): igual en los dos modos.
  static const marca = Color(0xFF0F3D2A);
  static const barraArriba = LinearGradient(colors: [Color(0xFF0F3D2A), Color(0xFF17563C)]);

  /// Color de datos (cultivo, categoría, serie) pensado para fondo claro: de noche se aclara
  /// un poco para que se lea sobre el fondo oscuro.
  static Color deNoche(Color color) => oscuro ? Color.lerp(color, const Color(0xFFFFFFFF), 0.28)! : color;

  /// Tono suave de [color] para fondos de pastillas y avisos, legible en los dos modos.
  static Color suave(Color color, [double alfa = 0.10]) => color.withValues(alpha: oscuro ? alfa * 1.6 : alfa);
}

abstract final class Sombras {
  static List<BoxShadow> get suave => Paleta.oscuro
      ? const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))]
      : const [
          BoxShadow(color: Color(0x0A101814), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0A101814), blurRadius: 3, offset: Offset(0, 1)),
        ];
  static List<BoxShadow> get media => Paleta.oscuro
      ? const [BoxShadow(color: Color(0x59000000), blurRadius: 12, offset: Offset(0, 4))]
      : const [
          BoxShadow(color: Color(0x141E6B4C), blurRadius: 14, offset: Offset(0, 6)),
          BoxShadow(color: Color(0x0A101814), blurRadius: 3, offset: Offset(0, 1)),
        ];
  static List<BoxShadow> get alta => Paleta.oscuro
      ? const [BoxShadow(color: Color(0x80000000), blurRadius: 28, offset: Offset(0, 10))]
      : const [
          BoxShadow(color: Color(0x1F0E3B27), blurRadius: 28, offset: Offset(0, 10)),
          BoxShadow(color: Color(0x0F101E16), blurRadius: 6, offset: Offset(0, 2)),
        ];
}
