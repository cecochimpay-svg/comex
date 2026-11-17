import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'paleta.dart';

/// Letra del sistema en Windows (como el panel de oficina); en el resto, la de la plataforma.
String? get fuenteComex => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows ? 'Segoe UI' : null;

/// Tema compacto "oficina", armado con los colores del modo actual ([Paleta.oscuro]).
/// Se vuelve a pedir en cada build de la app, así un cambio de modo lo rehace entero.
ThemeData temaComex() {
  final oscuro = Paleta.oscuro;
  final fuente = fuenteComex;
  final esquema =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E6B4C),
        brightness: oscuro ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: Paleta.verde,
        onPrimary: Colors.white,
        primaryContainer: Paleta.filaSel,
        onPrimaryContainer: Paleta.verdeTitulo,
        secondary: Paleta.oro,
        onSecondary: Colors.white,
        surface: Paleta.superficie,
        onSurface: Paleta.tinta,
        onSurfaceVariant: Paleta.tintaSuave,
        surfaceContainerLowest: Paleta.superficie,
        surfaceContainerLow: Paleta.superficie,
        surfaceContainer: Paleta.superficie,
        surfaceContainerHigh: Paleta.superficieSuave,
        surfaceContainerHighest: Paleta.superficieSuave,
        outline: Paleta.borde,
        outlineVariant: Paleta.bordeSuave,
        error: Paleta.peligro,
        onError: Colors.white,
        surfaceTint: Colors.transparent,
      );
  final base = ThemeData(useMaterial3: true, colorScheme: esquema, fontFamily: fuente);
  final t = base.textTheme.apply(bodyColor: Paleta.tinta, displayColor: Paleta.tinta);
  final radio = BorderRadius.circular(8);
  final radioCampo = BorderRadius.circular(8);
  TextStyle letra(double tamano, FontWeight peso, [Color? color]) =>
      TextStyle(fontFamily: fuente, fontSize: tamano, fontWeight: peso, color: color);

  OutlineInputBorder bordeCampo(Color color, [double ancho = 1]) => OutlineInputBorder(
    borderRadius: radioCampo,
    borderSide: BorderSide(color: color, width: ancho),
  );
  final bordeInput = Paleta.dual(0xFFCAD3CD, 0xFF313B36);

  return base.copyWith(
    scaffoldBackgroundColor: Paleta.fondo,
    canvasColor: Paleta.superficie,
    cardColor: Paleta.superficie,
    textTheme: t.copyWith(
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w400),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
      titleMedium: t.titleMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      labelLarge: t.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    iconTheme: base.iconTheme.copyWith(color: Paleta.tintaSuave),
    dividerColor: Paleta.bordeSuave,
    dividerTheme: DividerThemeData(color: Paleta.bordeSuave, space: 1, thickness: 1),
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.compact,
    cardTheme: CardThemeData(
      color: Paleta.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Paleta.borde),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Paleta.superficie,
      hoverColor: Paleta.dual(0xFFF7FAF8, 0xFF1D2621),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: bordeCampo(bordeInput),
      enabledBorder: bordeCampo(bordeInput),
      disabledBorder: bordeCampo(Paleta.bordeSuave),
      focusedBorder: bordeCampo(Paleta.verde, 1.4),
      errorBorder: bordeCampo(Paleta.peligro),
      focusedErrorBorder: bordeCampo(Paleta.peligro, 1.4),
      prefixIconColor: Paleta.tintaTenue,
      suffixIconColor: Paleta.tintaTenue,
      labelStyle: letra(13, FontWeight.w500, Paleta.tintaSuave),
      floatingLabelStyle: letra(13, FontWeight.w600, Paleta.verde),
      hintStyle: letra(13, FontWeight.w400, Paleta.tintaTenue),
      helperStyle: letra(11, FontWeight.w400, Paleta.tintaTenue),
      errorStyle: letra(11, FontWeight.w500, Paleta.peligro),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Paleta.verde,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Paleta.borde,
        disabledForegroundColor: Paleta.tintaTenue,
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: radio),
        textStyle: letra(13, FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Paleta.tinta,
        backgroundColor: Paleta.superficie,
        side: BorderSide(color: Paleta.borde),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: radio),
        textStyle: letra(13, FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Paleta.verde,
        minimumSize: const Size(48, 34),
        shape: RoundedRectangleBorder(borderRadius: radio),
        textStyle: letra(13, FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Paleta.tintaSuave)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Paleta.verdeSuave : Paleta.superficie,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Paleta.verdeTitulo : Paleta.tintaSuave,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: Paleta.borde)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Paleta.superficie,
      disabledColor: Paleta.superficieSuave,
      selectedColor: Paleta.verdeSuave,
      side: BorderSide(color: Paleta.borde),
      labelStyle: letra(12, FontWeight.w600, Paleta.tinta),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Paleta.verde : Paleta.bordeSuave,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : Paleta.tintaTenue,
      ),
      trackOutlineColor: WidgetStatePropertyAll(Paleta.borde),
    ),
    checkboxTheme: CheckboxThemeData(
      side: BorderSide(color: Paleta.tintaTenue, width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Paleta.verde : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Paleta.verde : Paleta.tintaTenue,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: const BoxDecoration(color: Paleta.marca, borderRadius: BorderRadius.all(Radius.circular(6))),
      textStyle: letra(11.5, FontWeight.w500, Colors.white),
      waitDuration: const Duration(milliseconds: 400),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Paleta.superficie,
      contentTextStyle: letra(13, FontWeight.w500, Paleta.tinta),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: radio,
        side: BorderSide(color: Paleta.borde),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Paleta.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Paleta.borde),
      ),
      titleTextStyle: letra(16, FontWeight.w700, Paleta.verdeTitulo),
      contentTextStyle: letra(13, FontWeight.w400, Paleta.tinta),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Paleta.fondo,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Paleta.bordeFuerte,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Paleta.superficie,
      surfaceTintColor: Colors.transparent,
      textStyle: letra(13, FontWeight.w400, Paleta.tinta),
      shape: RoundedRectangleBorder(
        borderRadius: radio,
        side: BorderSide(color: Paleta.borde),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Paleta.superficie),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: radio,
            side: BorderSide(color: Paleta.borde),
          ),
        ),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(Paleta.superficie)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Paleta.superficie,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: Paleta.marca,
      headerForegroundColor: Colors.white,
      dividerColor: Paleta.borde,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Paleta.superficie,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Paleta.verdeSuave,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => letra(
          11.5,
          s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          s.contains(WidgetState.selected) ? Paleta.verdeTitulo : Paleta.tintaSuave,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Paleta.verde : Paleta.tintaSuave),
      ),
    ),
    listTileTheme: ListTileThemeData(
      dense: true,
      iconColor: Paleta.tintaSuave,
      textColor: Paleta.tinta,
      selectedColor: Paleta.verdeTitulo,
      selectedTileColor: Paleta.filaSel,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: Paleta.verde, linearTrackColor: Paleta.bordeSuave),
    badgeTheme: BadgeThemeData(backgroundColor: Paleta.oro, textColor: Colors.white),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(10),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.hovered) ? Paleta.verde : Paleta.dual(0xFFC4CCC6, 0xFF353936),
      ),
    ),
  );
}
