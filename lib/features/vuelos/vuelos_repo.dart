import 'dart:math';

import '../../core/auth/sesion.dart';
import '../../core/config.dart';
import '../../core/datos/datos_nube.dart';
import '../../core/formato.dart';
import 'vuelos_datos.dart';

/// Lectura y guardado de despachos en `logistitcas_temporada` (con copia local sin conexión).
/// Reglas de la versión Electron: ADM / ADMIN ven todos los de la temporada; COMEX sólo los suyos.
abstract final class RepoVuelos {
  static const tabla = 'logistitcas_temporada';
  static const clave = 'registro';

  static String alcance(Sesion s) =>
      '${Config.temporada}|${s.esAdministrador ? '*' : s.nombre.trim().toLowerCase()}';

  static Future<({List<Vuelo> vuelos, bool offline})> cargar(Sesion s) async {
    final l = await DatosNube.leer(
      tabla: tabla,
      clave: clave,
      alcance: alcance(s),
      consulta: (nube) async {
        var q = nube.from(tabla).select().eq('temporada', Config.temporada);
        // ilike sin comodines: "_" y "%" del nombre se escapan (si no, "j_lopez" traería también "jxlopez").
        if (!s.esAdministrador) q = q.ilike('usuario', patronExacto(s.nombre.trim()));
        return await q.order('semana', ascending: false);
      },
    );
    return (vuelos: [for (final f in l.filas) Vuelo(f)], offline: l.offline);
  }

  /// Guarda lo que se cargó en el formulario. Sólo se mandan las columnas de la planilla: en un registro
  /// viejo, línea aérea, origen, cliente final, etc. quedan como estaban.
  /// Devuelve (sincronizado, columnas que la nube no tiene todavía).
  static Future<({bool enNube, List<String> omitidas})> guardar(
    Sesion s,
    DatosFormularioVuelo d, {
    Vuelo? previo,
  }) async {
    String? t(String v) => v.trim().isEmpty ? null : v.trim();
    String? may(String v) => t(v)?.toUpperCase();

    // Semana y fecha del despacho: por ETD, si no por ingreso TCA; al editar uno sin ninguna de las dos,
    // se respeta la fecha que ya tenía.
    final sinFechas = d.etdFecha.isEmpty && d.ingreso.isEmpty;
    final fechaPrevia = previo == null ? '' : txtFecha(previo.f['fecha']);
    final fechaBase = sinFechas && fechaPrevia.isNotEmpty
        ? fechaPrevia
        : (d.etdFecha.isNotEmpty ? d.etdFecha : (d.ingreso.isNotEmpty ? d.ingreso : hoyIso()));

    final fila = <String, Object?>{
      'registro': previo?.registro ?? nuevoRegistro(),
      'temporada': Config.temporada,
      'semana': semanaDeDespacho(etd: fechaBase),
      'fecha': fechaBase,
      'awb': t(d.awb),
      'ingreso': t(d.ingreso),
      'destino': may(d.destino),
      'ruta': may(d.ruta),
      'vuelo': may(d.vuelo),
      'proforma': t(d.proforma),
      'fecha_etd1': t(d.etdFecha),
      'hora_etd1': t(d.etdHora),
      'vuelo_cnx': may(d.conex),
      'pcs': d.tarimas,
      'kilos': d.peso,
      'tarifa_kg': normalizarTarifa(d.tarifa),
      'status': may(d.status),
      'consignatario': t(d.cnne),
      'usuario': previo?.usuario.isNotEmpty == true ? previo!.usuario : s.nombre,
    };
    // Registro viejo con ETA del tramo 2: se actualiza esa; si no, la del tramo 1.
    if (previo?.etaEnTramo2 ?? false) {
      fila['fecha_eta_2'] = t(d.etaFecha);
      fila['hora_eta2'] = t(d.etaHora);
    } else {
      fila['fecha_eta_1'] = t(d.etaFecha);
      fila['hora_eta1'] = t(d.etaHora);
    }
    if (previo == null) fila['cliente'] = 'CECO';

    final omitidas = <String>[];
    final enNube = await DatosNube.guardar(
      tabla: tabla,
      clave: clave,
      alcance: alcance(s),
      fila: fila,
      copiaLocal: previo?.f,
      omitidas: omitidas,
    );
    return (enNube: enNube, omitidas: omitidas);
  }

  static Future<bool> borrar(Vuelo v) => DatosNube.borrar(tabla: tabla, clave: clave, valor: v.registro);

  /// Mismo formato que la versión Electron: 8 letras y números al azar.
  static String nuevoRegistro() {
    const letras = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random.secure();
    return List.generate(8, (_) => letras[r.nextInt(letras.length)]).join();
  }

  /// Patrón de LIKE que coincide sólo con [texto] tal cual (sin distinguir mayúsculas con ilike).
  static String patronExacto(String texto) =>
      texto.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');

  static String txtFecha(Object? v) {
    final s = v == null ? '' : '$v'.trim();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }
}

/// Lo que se carga en el formulario (las columnas de la planilla).
class DatosFormularioVuelo {
  const DatosFormularioVuelo({
    required this.awb,
    required this.ingreso,
    required this.destino,
    required this.ruta,
    required this.vuelo,
    required this.proforma,
    required this.etdFecha,
    required this.etdHora,
    required this.conex,
    required this.etaFecha,
    required this.etaHora,
    required this.tarimas,
    required this.peso,
    required this.tarifa,
    required this.status,
    required this.cnne,
  });

  final String awb;
  final String ingreso;
  final String destino;
  final String ruta;
  final String vuelo;
  final String proforma;
  final String etdFecha;
  final String etdHora;
  final String conex;
  final String etaFecha;
  final String etaHora;
  final int tarimas;
  final int peso;
  final String tarifa;
  final String status;
  final String cnne;
}
