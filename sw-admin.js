self.addEventListener('install', function(e) {
  self.skipWaiting();
});

self.addEventListener('activate', function(e) {
  e.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', function(e) {
  // Solo interceptar peticiones GET
  if (e.request.method !== 'GET') return;

  e.respondWith(
    fetch(e.request).catch(function() {
      return caches.match(e.request).then(function(response) {
        // Si no hay respuesta en caché, devolver una respuesta vacía válida para no romper la app
        return response || new Response('', { status: 404, statusText: 'Not Found' });
      });
    })
  );
});
