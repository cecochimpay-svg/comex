import 'package:supabase_flutter/supabase_flutter.dart';

final _patronRed = RegExp(
  r'SocketException|ClientException|Failed host lookup|XMLHttpRequest|fetch failed|network|timed? ?out|Connection (refused|closed|reset)|Retryable',
  caseSensitive: false,
);

/// Error de red (sin internet / Supabase caído) => se trabaja offline.
bool esErrorDeRed(Object error) => _patronRed.hasMatch('${error.runtimeType} $error');

final _patronPermiso = RegExp(r'row-level security|permission denied|JWT', caseSensitive: false);

/// La nube rechazó la operación por permisos (RLS / sesión vencida).
bool esErrorPermiso(Object error) {
  if (error is PostgrestException) {
    return error.code == '42501' || error.code == 'PGRST301' || _patronPermiso.hasMatch(error.message);
  }
  return false;
}

final _identificador = RegExp(r'^[\p{L}_][\p{L}\p{N}_]{0,62}$', unicode: true);

/// Nombres de tabla/columna que vienen de la nube se validan antes de armar SQL local.
bool esIdentValido(String nombre) => _identificador.hasMatch(nombre);

/// Mensaje legible de una excepción de Supabase.
String mensajeDe(Object error) => switch (error) {
      AuthException(:final message) => message,
      PostgrestException(:final message) => message,
      StorageException(:final message) => message,
      _ => '$error',
    };
