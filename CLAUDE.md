# COMEX — versión Flutter

Migración de la app Electron/web `C:\APPS VARIAS\comex` (carpeta hermana) a Flutter para Windows, macOS, iOS,
Android y web. Misma lógica y mismas tablas de Supabase; estética "oficina" copiada de
`C:\Doc_Juan\Doc_Juanchi\2026\SISTEMAS NUEVOS\202610\salvucci_flutter` (modo claro y noche).

## Supabase (compartido)
- Proyecto `veqpyhifwubcdxocckmf`: lo comparten COMEX, COMEX Despachos y etiquetado. No renombrar tablas ni
  columnas: Despachos lee `logistitcas_temporada` (sí, con esa falta de ortografía) y los programas.
- RLS de `supabase/migraciones/004_acceso_con_sesion.sql` (repo comex): sin sesión de Supabase Auth no hay datos.
- Migraciones SQL: siguen viviendo en el repo comex (`supabase/migraciones/`). La 006 agrega proforma/ruta/status.

## Estructura
- `lib/core/auth/` login: RPC `comex_login` → Supabase Auth con `Config.correoInterno(usuario)`
  (`<usuario>@comex.cecoargentina.com`); sin internet, verificador scrypt local (7 días). Sesión 12 h.
- `lib/core/datos/datos_nube.dart` acceso a tablas con copia local genérica (tabla SQLite `filas`, JSON por fila):
  `leer` (nube → copia; sin red, la copia), `guardar` / `borrar` (sin red quedan pendientes). Los cambios
  pendientes nunca los pisa una bajada. `alcance` = qué parte de la tabla trae cada consulta.
- `lib/core/sync/servicio_sync.dart` sube pendientes; `clavesTablas` = columna clave de cada tabla que se escribe
  (sumar ahí cada tabla nueva). `version` cambia en cada sincronización: las pantallas la escuchan para releer.
- `lib/core/nav/catalogo.dart` áreas y pantallas; `soloAdministrador` las oculta a COMEX. `sesionVisible`
  (lo fija `SesionController`) filtra menú y buscador. Después del login va a `rutaInicial` (Vuelos).
- `lib/features/vuelos/` despachos con las columnas de la planilla de logística (TCI): AWB · Ingreso TCA ·
  Destino · Ruta · Vuelo · Proforma · ETD · Conex · ETA · Tarimas · Peso · Tarifa · Status · CNNE.
  Status con LED. Semana = ISO de la ETD (si no, del ingreso TCA). Al editar se mandan sólo esas columnas: los
  campos viejos (línea aérea, origen, cliente_final, ULD) quedan como estaban. `kilos` y `pcs` son enteros.
  ADM ve todo y no edita; COMEX ve y edita lo suyo (`usuario`).
- Importar Excel (sólo COMEX): `lib/core/importar/lector_xlsx.dart` lee el .xlsx sin plugins (anda en web/iPad);
  `vuelos/importar_vuelos.dart` reconoce columnas por título (`_sinonimos`: planilla TCI y la completa de
  Jetcargo), empareja por AWB en orden (sin AWB: vuelo+ETD+destino), manda sólo lo que cambió, celda vacía no
  borra y nunca elimina. `importar_dialogo.dart` = vista previa. Tests: `test/importar_vuelos_test.dart`.
- Usuarios externos (rol `EXTERNO` en comex_usuarios, migración 007 del repo comex): RLS les deja leer y tocar
  sólo sus vuelos, nada de programa/proyección/clientes. Los internos y COMEX Despachos siguen leyendo todos
  los vuelos (Despachos los necesita para el packing list): no cerrar la lectura para todos.
- Avisos al ADM: trigger `comex_vuelos_avisar` (007) llena `comex_notificaciones` con altas/ediciones/bajas de
  quien no es ADM; `lib/core/avisos/avisos_admin.dart` (tiempo real + relectura cada 2 min) y
  `features/shell/panel_avisos.dart` (tarjetas flotantes en `AppShell` hasta que el ADM las cierra).
- `lib/features/programa/` programa de trabajo (sólo ADM).
- `lib/features/home/resumen_*.dart` números del menú, leídos de la copia local.
- `lib/widgets/`, `lib/core/tema/`, `lib/core/exportar/` vienen de salvucci_flutter sin cambios de fondo: seguir
  sus reglas (Paleta son getters, nada de `const` con Paleta, nada de `Colors.white` de fondo).

## Comandos (SDK en `C:\src\flutter\bin\flutter`)
- `flutter analyze` tiene que quedar en "No issues found!".
- `flutter test` — `test/vuelos_pantalla_test.dart` dibuja Vuelos sin internet; `--update-goldens` regenera
  las capturas de `test/capturas/`.
- Instructivo del usuario COMEX: `dart run tool/instructivo_comex.dart` → `docs/Instructivo_COMEX_usuario.pdf`.
- Íconos: `dart run flutter_launcher_icons`. Web: `web/sqlite3.wasm` y `web/sqflite_sw.js` ya están.
