const etiquetasRol = <String, String>{
  'ADM': 'Administración',
  'ADMIN': 'Administración',
  'COMEX': 'Comercio exterior',
};

/// Usuario logueado en este equipo.
class Sesion {
  const Sesion({
    required this.usuarioId,
    required this.nombre,
    required this.rol,
    required this.correo,
    required this.offline,
  });

  final int usuarioId;

  /// Nombre de usuario de comex_usuarios (es el que queda en la columna "usuario" de cada vuelo).
  final String nombre;
  final String rol;

  /// Correo interno de Supabase Auth (`<usuario>@comex.cecoargentina.com`).
  final String correo;

  /// Entró sin conexión con la nube (validado contra el verificador local).
  final bool offline;

  /// ADM / ADMIN ven todo (auditoría y programa de trabajo); COMEX carga sus despachos.
  bool get esAdministrador {
    final r = rol.toUpperCase();
    return r == 'ADM' || r == 'ADMIN' || nombre.toUpperCase() == 'ADMIN';
  }

  String get rolEtiqueta => etiquetasRol[rol.toUpperCase()] ?? rol;

  String get primerNombre => nombre.trim().split(RegExp(r'\s+')).first;

  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'[\s._-]+')).where((p) => p.isNotEmpty).take(2);
    final ini = partes.map((p) => p[0].toUpperCase()).join();
    return ini.isEmpty ? '—' : ini;
  }
}

class ResultadoLogin {
  const ResultadoLogin.ok(Sesion this.sesion) : error = null;
  const ResultadoLogin.error(String this.error) : sesion = null;

  final Sesion? sesion;
  final String? error;

  bool get ok => sesion != null;
}
