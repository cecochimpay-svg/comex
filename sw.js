// Service worker de COMEX (versión web): primero la red, y si no hay conexión se usa la copia guardada.
// Los datos (Supabase) nunca se guardan acá: solo los archivos de la app.
const CACHE = 'comex-v1';
const ARCHIVOS = [
  './',
  './index.html',
  './loguer.html',
  './logo.png',
  './manifest.webmanifest',
  './iconos/icono-192.png',
  './iconos/icono-512.png',
  './seguridad/seguridad.js',
  './compartido/pdf-comex.js',
  './estilos/comex-ui.css',
  './vendor/supabase-2.109.0.js',
  './vendor/jspdf-2.5.1.umd.min.js',
  './vendor/jspdf.plugin.autotable-3.5.31.min.js',
  './programa/programa_trab.html',
  './vuelos/vuelos_comex.html'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ARCHIVOS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(claves => Promise.all(claves.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== location.origin) return;
  e.respondWith(
    fetch(e.request)
      .then(resp => {
        if (resp.ok) {
          const copia = resp.clone();
          caches.open(CACHE).then(c => c.put(e.request, copia));
        }
        return resp;
      })
      .catch(() => caches.match(e.request, { ignoreSearch: true }))
  );
});
