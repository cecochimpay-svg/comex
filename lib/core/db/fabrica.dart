// Abre la base SQLite con el motor de cada plataforma:
//   Android / iOS -> sqflite · Windows / macOS / Linux -> FFI · Web -> WASM (IndexedDB)
export 'fabrica_stub.dart'
    if (dart.library.js_interop) 'fabrica_web.dart'
    if (dart.library.io) 'fabrica_io.dart';
