import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/sesion_controller.dart';
import '../../core/db/filas.dart';
import '../../core/formato.dart';
import '../../core/importar/lector_xlsx.dart';
import '../../core/red.dart';
import '../../core/tema/paleta.dart';
import '../../widgets/avisos.dart';
import '../../widgets/comunes.dart';
import '../../widgets/formulario.dart';
import '../../widgets/listados.dart';
import 'importar_vuelos.dart';
import 'vuelos_datos.dart';

/// Botón "Importar Excel" de Vuelos: elige el .xlsx, muestra qué se crea y qué se actualiza y,
/// si se confirma, lo guarda. Devuelve el resultado (null si se canceló).
Future<ResultadoImport?> importarPlanillaVuelos(BuildContext context, List<Vuelo> existentes) async {
  final PlatformFile? archivo;
  try {
    archivo = await FilePicker.pickFile(
      dialogTitle: 'Elegí la planilla de despachos (.xlsx)',
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
  } catch (e) {
    if (context.mounted) mostrarAviso(context, 'No se pudo abrir el selector de archivos: ${mensajeDe(e)}', tipo: TipoAviso.error);
    return null;
  }
  if (archivo == null || !context.mounted) return null;

  final PlanillaLeida planilla;
  try {
    planilla = leerPlanillaVuelos(await archivo.readAsBytes());
  } on ArchivoInvalido catch (e) {
    if (context.mounted) mostrarAviso(context, e.mensaje, tipo: TipoAviso.error);
    return null;
  } catch (e) {
    if (context.mounted) mostrarAviso(context, 'No se pudo leer el Excel: ${mensajeDe(e)}', tipo: TipoAviso.error);
    return null;
  }
  if (!context.mounted) return null;
  if (planilla.filas.isEmpty) {
    mostrarAviso(context, 'La planilla no tiene despachos debajo de los títulos.', tipo: TipoAviso.aviso);
    return null;
  }

  return showDialog<ResultadoImport>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoImportar(
      archivo: archivo!.name,
      planilla: planilla,
      plan: compararConExistentes(planilla, existentes),
    ),
  );
}

class _DialogoImportar extends StatefulWidget {
  const _DialogoImportar({required this.archivo, required this.planilla, required this.plan});

  final String archivo;
  final PlanillaLeida planilla;
  final List<CambioImport> plan;

  @override
  State<_DialogoImportar> createState() => _DialogoImportarState();
}

class _DialogoImportarState extends State<_DialogoImportar> {
  bool _guardando = false;
  int _hechos = 0;
  int _total = 0;
  bool _verIguales = false;
  String? _error;

  int _cuantos(TipoCambio t) => widget.plan.where((c) => c.tipo == t).length;

  Future<void> _importar() async {
    final sesion = context.read<SesionController>().actual!;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final r = await aplicarImportacion(
        sesion,
        widget.plan,
        progreso: (h, t) {
          if (mounted) {
            setState(() {
              _hechos = h;
              _total = t;
            });
          }
        },
      );
      if (mounted) Navigator.pop(context, r);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No se pudo importar: ${mensajeDe(e)}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nuevos = _cuantos(TipoCambio.nuevo);
    final cambian = _cuantos(TipoCambio.actualiza);
    final iguales = _cuantos(TipoCambio.igual);
    final errores = _cuantos(TipoCambio.error);
    final aGuardar = nuevos + cambian;
    final p = widget.planilla;

    // Primero lo que necesita atención (errores), después nuevos y cambios; los iguales, a pedido.
    final orden = {TipoCambio.error: 0, TipoCambio.nuevo: 1, TipoCambio.actualiza: 2, TipoCambio.igual: 3};
    final visibles = [
      for (final c in widget.plan)
        if (c.tipo != TipoCambio.igual || _verIguales) c,
    ]..sort((a, b) {
        final o = orden[a.tipo]!.compareTo(orden[b.tipo]!);
        return o != 0 ? o : a.fila.numero.compareTo(b.fila.numero);
      });
    const maximo = 300;

    return MarcoDialogo(
      titulo: 'Importar planilla',
      subtitulo: '${widget.archivo} · hoja "${p.hoja}" · títulos en la fila ${p.filaEncabezado}',
      icono: Icons.upload_file_rounded,
      tono: Paleta.azul,
      anchoMaximo: 920,
      error: _error,
      acciones: [
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: _guardando || aGuardar == 0 ? null : _importar,
          icon: _guardando
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.cloud_upload_rounded, size: 18),
          label: Text(
            _guardando
                ? 'Guardando $_hechos de $_total…'
                : aGuardar == 0
                    ? 'No hay nada para importar'
                    : 'Importar ${fmtNum(aGuardar)} despacho(s)',
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_guardando) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: _total == 0 ? null : _hechos / _total, minHeight: 6),
            ),
            const SizedBox(height: 14),
          ],
          GrillaAdaptable(
            anchoMinimo: 190,
            maxColumnas: 4,
            espacio: 10,
            children: [
              DatoResumen(
                rotulo: 'Nuevos',
                valor: fmtNum(nuevos),
                detalle: 'se crean',
                color: Paleta.exito,
                icono: Icons.add_circle_outline_rounded,
              ),
              DatoResumen(
                rotulo: 'Se actualizan',
                valor: fmtNum(cambian),
                detalle: 'ya estaban, con cambios',
                color: Paleta.azul,
                icono: Icons.sync_alt_rounded,
              ),
              DatoResumen(
                rotulo: 'Sin cambios',
                valor: fmtNum(iguales),
                detalle: 'quedan como están',
                color: Paleta.pizarra,
                icono: Icons.check_rounded,
              ),
              DatoResumen(
                rotulo: 'Con error',
                valor: fmtNum(errores),
                detalle: errores == 0 ? 'ninguno' : 'no se importan',
                color: errores == 0 ? Paleta.pizarra : Paleta.peligro,
                icono: Icons.error_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SeccionForm(
            titulo: 'Columnas reconocidas',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final c in p.columnas) Pastilla(texto: c.etiqueta, color: Paleta.verde)],
                ),
                const SizedBox(height: 8),
                Text(
                  'Las demás columnas (semana, día, cajas, fuel…) no se usan. Una celda vacía no borra lo '
                  'que ya estaba cargado y no se elimina ningún despacho.'
                  '${p.ignoradas == 0 ? '' : ' Se saltearon ${p.ignoradas} fila(s) de títulos o semanas.'}',
                  style: TextStyle(fontSize: 12, color: Paleta.tintaSuave),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'DETALLE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Paleta.tintaSuave),
                ),
              ),
              if (iguales > 0)
                TextButton.icon(
                  onPressed: () => setState(() => _verIguales = !_verIguales),
                  icon: Icon(_verIguales ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16),
                  label: Text(_verIguales ? 'Ocultar sin cambios' : 'Ver sin cambios (${fmtNum(iguales)})'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (visibles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Todo lo de la planilla ya está cargado igual.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Paleta.tintaSuave),
              ),
            ),
          for (final c in visibles.take(maximo)) _FilaPlan(c: c),
          if (visibles.length > maximo)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '… y ${fmtNum(visibles.length - maximo)} fila(s) más.',
                style: TextStyle(fontSize: 12, color: Paleta.tintaSuave),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaPlan extends StatelessWidget {
  const _FilaPlan({required this.c});

  final CambioImport c;

  @override
  Widget build(BuildContext context) {
    final (etiqueta, color) = switch (c.tipo) {
      TipoCambio.nuevo => ('NUEVO', Paleta.exito),
      TipoCambio.actualiza => ('CAMBIA', Paleta.azul),
      TipoCambio.igual => ('IGUAL', Paleta.pizarra),
      TipoCambio.error => ('ERROR', Paleta.peligro),
    };
    final d = c.tipo == TipoCambio.nuevo ? c.cambios : {...?c.previo?.f, ...c.cambios};
    String v(String k) => txt(d[k]);
    final etd = v('fecha_etd1');
    final resumen = [
      v('awb').isEmpty ? 'Sin AWB' : 'AWB ${v('awb')}',
      if (v('vuelo').isNotEmpty) v('vuelo'),
      if (v('destino').isNotEmpty) v('destino'),
      if (etd.isNotEmpty) 'ETD ${fechaTabla(etd)}${v('hora_etd1').isEmpty ? '' : ' ${v('hora_etd1')}'}',
      if (v('pcs').isNotEmpty) '${fmtNum(numDe(d['pcs']))} tarimas',
    ].join(' · ');
    final chico = TextStyle(fontSize: 12, color: Paleta.tintaSuave);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.tipo == TipoCambio.error ? Paleta.peligro.withValues(alpha: 0.4) : Paleta.bordeSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 62, child: Align(alignment: Alignment.centerLeft, child: Pastilla(texto: etiqueta, color: color))),
              SizedBox(width: 58, child: Text('Fila ${c.fila.numero}', style: chico)),
              Expanded(
                child: Text(
                  resumen,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Paleta.tinta),
                ),
              ),
            ],
          ),
          if (c.error != null) _linea(Icons.error_outline_rounded, c.error!, Paleta.peligro),
          for (final (dato, antes, despues) in c.detalle)
            _linea(Icons.arrow_right_alt_rounded, '$dato: $antes → $despues', Paleta.tinta),
          for (final a in c.fila.avisos) _linea(Icons.warning_amber_rounded, a, Paleta.oro),
        ],
      ),
    );
  }

  Widget _linea(IconData icono, String texto, Color color) => Padding(
    padding: const EdgeInsets.only(left: 120, top: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 5),
        Expanded(child: Text(texto, style: TextStyle(fontSize: 12, color: color))),
      ],
    ),
  );
}
