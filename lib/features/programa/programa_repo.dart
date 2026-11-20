import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/datos/datos_nube.dart';
import '../../core/db/filas.dart';
import '../../core/red.dart';
import 'programa_datos.dart';

/// Lecturas y escrituras del Programa de trabajo. Mismas tablas, columnas y claves que la versión
/// Electron (COMEX Despachos lee estas tablas):
///   comex_proyeccion_dias   una fila por fecha y usuario (onConflict 'fecha,usuario')
///   comex_programa_trabajo  un renglón por calibre (id), agrupados por programa_nro
///   logistitcas_temporada   sólo lectura (vuelos de la temporada)
///   clientes_consignatarios / agronet_marcas  sólo lectura (catálogos)
abstract final class RepoPrograma {
  static const tablaProgramas = 'comex_programa_trabajo';
  static const tablaProyeccion = 'comex_proyeccion_dias';
  static const _alcanceTemporada = '${Config.temporada}';

  // La pantalla de Vuelos guarda su propia copia de logistitcas_temporada; ésta se guarda aparte
  // (otro nombre en la copia local) para no mezclar los alcances de las dos pantallas.
  static const _copiaVuelos = 'programa_vuelos';

  static String _claveProyeccion(Object? fecha, Object? usuario) =>
      '${soloFecha(fecha)}|${txt(usuario).toLowerCase()}';

  static Future<DatosPrograma> cargar(String usuario) async {
    final yo = usuario.trim().toLowerCase();
    final resultados = await Future.wait([
      DatosNube.leer(
        tabla: _copiaVuelos,
        clave: 'registro',
        alcance: _alcanceTemporada,
        consulta: (n) => n.from('logistitcas_temporada').select().eq('temporada', Config.temporada),
      ),
      DatosNube.leer(
        tabla: tablaProyeccion,
        clave: 'fecha,usuario',
        alcance: 'todas',
        claveDe: (f) => _claveProyeccion(f['fecha'], f['usuario']),
        consulta: (n) => n.from(tablaProyeccion).select().order('fecha', ascending: true),
      ),
      DatosNube.leer(
        tabla: tablaProgramas,
        clave: 'id',
        alcance: _alcanceTemporada,
        consulta: (n) =>
            n.from(tablaProgramas).select().eq('temporada', Config.temporada).order('fecha', ascending: false),
      ),
      _catalogo(
        tabla: 'clientes_consignatarios',
        clave: 'id',
        alcance: 'activos',
        consulta: (n) => n
            .from('clientes_consignatarios')
            .select('id, cliente, consignatario, destino, activo')
            .eq('activo', true)
            .order('cliente'),
      ),
      _catalogo(
        tabla: 'agronet_marcas',
        clave: 'id_marca',
        alcance: 'activas',
        consulta: (n) =>
            n.from('agronet_marcas').select('id_marca, detalle, abreviatura, activo').eq('activo', true).order('detalle'),
      ),
    ]);
    final vuelos = resultados[0], proy = resultados[1], prog = resultados[2];

    // Proyección: la del usuario, o la que no tiene usuario (la propia gana si están las dos).
    final proyecciones = <String, Fila>{};
    for (final p in proy.filas) {
      final u = txt(p['usuario']).toLowerCase();
      if (u.isNotEmpty && u != yo) continue;
      final f = soloFecha(p['fecha']);
      if (u.isEmpty && proyecciones.containsKey(f)) continue;
      proyecciones[f] = p;
    }

    // Programas: por fecha descendente (la copia local no conserva el orden de la consulta).
    final renglones = [...prog.filas]
      ..sort((a, b) {
        final c = soloFecha(b['fecha']).compareTo(soloFecha(a['fecha']));
        return c != 0 ? c : numDe(a['id']).compareTo(numDe(b['id']));
      });

    final clientes = <String, List<OpcionConsignatario>>{};
    final cc = [...resultados[3].filas]..sort((a, b) => numDe(a['id']).compareTo(numDe(b['id'])));
    for (final f in cc) {
      final cli = txt(f['cliente']);
      if (cli.isEmpty) continue;
      clientes.putIfAbsent(cli, () => []).add(OpcionConsignatario(txt(f['consignatario']), txt(f['destino'])));
    }

    final marcasFilas = [...resultados[4].filas]..sort((a, b) => txt(a['detalle']).compareTo(txt(b['detalle'])));
    final marcas = <OpcionMarca>[
      for (final m in marcasFilas)
        if (txt(m['detalle']).isNotEmpty)
          OpcionMarca(
            txt(m['detalle']),
            txt(m['abreviatura']).isNotEmpty && txt(m['abreviatura']) != txt(m['detalle'])
                ? '${txt(m['detalle'])} (${txt(m['abreviatura'])})'
                : txt(m['detalle']),
          ),
    ];

    return DatosPrograma(
      vuelos: vuelos.filas,
      proyecciones: proyecciones,
      renglones: renglones,
      clientes: clientes,
      marcas: marcas.isEmpty ? [for (final m in marcasReserva) OpcionMarca(m, m)] : marcas,
      offline: vuelos.offline || proy.offline || prog.offline,
    );
  }

  /// Los catálogos no deben trabar la pantalla: si la nube los rechaza (permisos), quedan vacíos.
  static Future<Lectura> _catalogo({
    required String tabla,
    required String clave,
    required String alcance,
    required Future<List<Map<String, dynamic>>> Function(SupabaseClient nube) consulta,
  }) async {
    try {
      return await DatosNube.leer(tabla: tabla, clave: clave, alcance: alcance, consulta: consulta);
    } catch (e) {
      if (esErrorDeRed(e)) rethrow;
      return const Lectura([], offline: false);
    }
  }

  /// N° de programa de la temporada que ya están en la nube, para no repetir uno que otro usuario acaba de
  /// guardar. Trae los renglones más nuevos (ahí están los números más altos). null = sin conexión.
  static Future<Set<String>?> nrosEnNube() async {
    try {
      final filas = await Supabase.instance.client
          .from(tablaProgramas)
          .select('programa_nro')
          .eq('temporada', Config.temporada)
          .order('id', ascending: false)
          .limit(1000)
          .timeout(DatosNube.limiteLectura);
      return {for (final f in filas) txt(f['programa_nro'])};
    } catch (_) {
      return null; // sin conexión: alcanza con el control contra la copia local
    }
  }

  /// Guarda los 11 días de la proyección (cosecha, inspección, carga y Ezeiza en kg).
  /// [valores]: fecha -> campo ('cosecha'…) -> kg. Devuelve false si quedó pendiente sin conexión.
  static Future<bool> guardarProyeccion({
    required DatosPrograma datos,
    required String usuario,
    required Map<String, Map<String, double>> valores,
  }) async {
    var enNube = true;
    final ahora = DateTime.now().toUtc().toIso8601String();
    for (final MapEntry(key: fecha, value: campos) in valores.entries) {
      final existente = datos.proyecciones[fecha];
      final fila = <String, Object?>{
        'temporada': Config.temporada,
        'fecha': fecha,
        'usuario': usuario,
        for (final (c, _) in conceptosProyeccion) '${c}_kg': campos[c] ?? 0,
        'updated_at': ahora,
        // El id sólo si la fila ya era de este usuario (si no, chocaría con la de otro).
        if (existente != null &&
            txt(existente['usuario']).toLowerCase() == usuario.toLowerCase() &&
            int.tryParse(txt(existente['id'])) != null)
          'id': int.parse(txt(existente['id'])),
      };
      final ok = await DatosNube.guardar(
        tabla: tablaProyeccion,
        clave: 'fecha,usuario',
        alcance: 'todas',
        fila: fila,
        valorClave: _claveProyeccion(fecha, usuario),
      );
      enNube &= ok;
    }
    return enNube;
  }

  /// Guarda un programa completo. En edición: los renglones con id se actualizan, los nuevos se insertan
  /// y los que se quitaron se borran ([originales] = renglones del programa antes de editar).
  /// Devuelve false si algo quedó pendiente por falta de conexión. [omitidas]: columnas que la nube no tiene.
  static Future<bool> guardarPrograma({
    required List<Map<String, Object?>> renglones,
    required List<Fila> originales,
    List<String>? omitidas,
  }) async {
    var enNube = true;
    final conservados = {for (final r in renglones) if (r['id'] != null) '${r['id']}'};
    final marca = DateTime.now().microsecondsSinceEpoch;
    for (final (i, r) in renglones.indexed) {
      final ok = await DatosNube.guardar(
        tabla: tablaProgramas,
        clave: 'id',
        alcance: _alcanceTemporada,
        fila: r,
        // Alta: todavía no tiene id; se inserta y la próxima lectura la trae con el suyo.
        valorClave: r['id'] == null ? 'tmp-$marca-$i' : null,
        omitidas: omitidas,
      );
      enNube &= ok;
    }
    for (final o in originales) {
      final id = int.tryParse(txt(o['id']));
      if (id != null && id > 0) {
        if (!conservados.contains('$id')) {
          enNube &= await DatosNube.borrar(tabla: tablaProgramas, clave: 'id', valor: '$id');
        }
      } else if (txt(o['_clave']).startsWith('tmp-')) {
        // Alta que todavía no había subido: se reemplaza por los renglones de esta edición.
        await DatosNube.descartarLocal(tabla: tablaProgramas, clave: txt(o['_clave']));
      }
    }
    return enNube;
  }
}
