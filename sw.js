// Service worker mínimo para que la app sea instalable (icono en el móvil).
// NO cachea nada: siempre va a la red, así nunca se queda una versión vieja.
self.addEventListener('install', e => self.skipWaiting());
self.addEventListener('activate', e => self.clients.claim());
self.addEventListener('fetch', e => { /* passthrough: lo maneja la red normalmente */ });
