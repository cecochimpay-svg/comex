import 'dart:convert';

/// Configuración general de COMEX (versión Flutter).
///
/// IMPORTANTE (seguridad):
/// - La clave "anon" viaja dentro de la app instalada: no es un secreto. Lo que protege los datos
///   son las políticas RLS (supabase/migraciones/004_acceso_con_sesion.sql del repo comex).
/// - NUNCA pongas acá la clave "service_role": esa sí da acceso total y saltea RLS.
/// - El proyecto de Supabase es el MISMO que usan COMEX Despachos y etiquetado.
/// - URL y clave se pueden cambiar sin tocar el código:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
abstract final class Config {
  static const appVersion = 'v3.0.0';

  /// Temporada de trabajo (vuelos y programas se filtran por este año).
  static const temporada = 2026;

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://veqpyhifwubcdxocckmf.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZlcXB5aGlmd3ViY2R4b2Nja21mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NzI5NzAsImV4cCI6MjA5MTQ0ODk3MH0.mIRsPLLoHn9jQtvCCwxG3aNFWtXIdcV12kLTC_MqybY',
  );

  /// La sesión local vence a las 12 h (igual que la versión Electron).
  static const sesionHoras = 12;

  /// Sin internet se puede entrar con la última clave validada en este equipo durante 7 días.
  static const diasIngresoOffline = 7;

  /// Correo interno de la cuenta de Supabase Auth de cada usuario (igual que public.comex_email()).
  static String correoInterno(String usuario) =>
      '${usuario.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '_')}@comex.cecoargentina.com';

  /// Defensa: nunca arrancar con una clave service_role embebida.
  static void validarClaveAnon() {
    try {
      final partes = supabaseAnonKey.split('.');
      if (partes.length < 2) return;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))));
      if (payload is Map && payload['role'] == 'service_role') {
        throw StateError('No se permite usar la clave service_role en la aplicación.');
      }
    } on StateError {
      rethrow;
    } catch (_) {
      // Clave con formato inesperado: Supabase la va a rechazar sola.
    }
  }
}
