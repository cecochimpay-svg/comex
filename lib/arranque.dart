import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/auth/auth_servicio.dart';
import 'core/avisos/avisos_admin.dart';
import 'core/auth/sesion_controller.dart';
import 'core/config.dart';
import 'core/db/base_local.dart';
import 'core/preferencias.dart';
import 'core/registro/registro.dart';
import 'core/sync/servicio_sync.dart';
import 'core/tema/modo_tema.dart';
import 'core/tema/paleta.dart';
import 'features/home/resumen_repo.dart';

/// Primera pantalla: se dibuja enseguida (la ventana nunca queda en negro esperando) y prepara la app
/// paso a paso. Si algo falla, lo muestra con el detalle y la ruta del registro, y permite reintentar.
class Arranque extends StatefulWidget {
  const Arranque({super.key});

  @override
  State<Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<Arranque> {
  String _paso = 'Iniciando…';
  Object? _error;
  String? _detalle;
  String? _rutaRegistro;
  Widget? _app;

  static bool _supabaseListo = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<T> _hacer<T>(String paso, Future<T> Function() accion, {Duration? limite}) async {
    if (mounted) setState(() => _paso = paso);
    await anotar('Arranque: $paso');
    final f = accion();
    return limite == null ? f : f.timeout(limite);
  }

  Future<void> _iniciar() async {
    setState(() {
      _error = null;
      _detalle = null;
    });
    try {
      await _hacer('Revisando la configuración…', () async => Config.validarClaveAnon());
      await _hacer('Preparando fechas…', () => initializeDateFormatting('es'));
      if (!_supabaseListo) {
        await _hacer(
          'Conectando con la nube…',
          () => Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseAnonKey),
        );
        _supabaseListo = true;
      }
      await _hacer('Abriendo la base local…', BaseLocal.abrir);

      final nube = Supabase.instance.client;
      final preferencias = await _hacer('Leyendo preferencias…', Preferencias.cargar);
      final modo = ModoTema(preferencias); // antes de dibujar la app: fija los colores del modo
      final sesion = SesionController(AuthServicio(nube));
      try {
        // Sin internet la sesión no debe trabar el arranque: si tarda, se sigue al login.
        await _hacer('Recuperando la sesión…', sesion.restaurar, limite: const Duration(seconds: 12));
      } on TimeoutException {
        await anotar('Arranque: la sesión tardó demasiado, se sigue sin restaurarla.');
      }
      final sync = ServicioSync(nube, preferencias);
      ResumenVivo.seguir(sync); // los números del menú se releen al guardar y al sincronizar
      // Avisos de cambios para el ADM: se prenden con su sesión y se apagan al salir.
      final avisos = AvisosAdmin(FuenteAvisosSupabase(nube));
      sesion.addListener(() => avisos.seguir(sesion.actual));
      unawaited(avisos.seguir(sesion.actual));
      await anotar('Arranque: listo.');

      // Pausa de 150 ms para garantizar que el compositor DirectX de Windows presente
      // el fotograma inicial y no congele la superficie al intercambiar de vista.
      await Future.delayed(const Duration(milliseconds: 150));

      if (!mounted) return;
      await anotar('Arranque: montando interfaz principal (ComexApp)...');
      setState(() {
        _app = MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: sesion),
            ChangeNotifierProvider.value(value: preferencias),
            ChangeNotifierProvider.value(value: modo),
            ChangeNotifierProvider.value(value: sync),
            ChangeNotifierProvider.value(value: avisos),
          ],
          child: ComexApp(sesion: sesion),
        );
      });
    } catch (e, s) {
      await anotar('ERROR en "$_paso": $e\n$s');
      final ruta = await rutaRegistro();
      if (!mounted) return;
      setState(() {
        _error = e;
        _detalle = '$_paso\n$e';
        _rutaRegistro = ruta;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_app != null) return _app!;
    return MaterialApp(
      key: const ValueKey('comex_splash_material'),
      debugShowCheckedModeBanner: false,
      title: 'COMEX',
      theme: ThemeData(scaffoldBackgroundColor: Paleta.marca),
      home: Scaffold(
        backgroundColor: Paleta.marca,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(padding: const EdgeInsets.all(24), child: _error == null ? _cargando() : _falla(context)),
          ),
        ),
      ),
    );
  }

  Widget _logo() => ClipOval(
    child: Image.asset(
      'assets/icono/icono.png',
      width: 84,
      height: 84,
      errorBuilder: (context, error, stack) => const SizedBox(width: 84, height: 84),
    ),
  );

  Widget _cargando() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _logo(),
        const SizedBox(height: 18),
        const Text(
          'COMEX',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 22),
        const SizedBox(
          width: 180,
          child: LinearProgressIndicator(color: Paleta.trigo, backgroundColor: Color(0x33FFFFFF)),
        ),
        const SizedBox(height: 12),
        Text(_paso, style: const TextStyle(color: Paleta.navTexto, fontSize: 13)),
      ],
    );
  }

  Widget _falla(BuildContext context) {
    final texto =
        'No se pudo iniciar COMEX.\n\n$_detalle'
        '${_rutaRegistro == null ? '' : '\n\nRegistro: $_rutaRegistro'}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _logo(),
        const SizedBox(height: 18),
        const Text(
          'No se pudo iniciar',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(10)),
          child: SelectableText(texto, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4)),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _iniciar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: FilledButton.styleFrom(backgroundColor: Paleta.trigo, foregroundColor: Paleta.marca),
            ),
            OutlinedButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: texto)),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar detalle'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0x88FFFFFF)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
