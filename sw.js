// sw.js — Service Worker de la PWA
// Estrategia: shell precacheado + network-first en navegación + stale-while-revalidate en estáticos.
// Los datos de Supabase (API y realtime) NUNCA se cachean.

const VERSION = 'dlv-v3';
const SHELL_CACHE = 'shell-' + VERSION;
const RUNTIME_CACHE = 'runtime-' + VERSION;
const OFFLINE_URL = '/index.html';

const SHELL = [
  '/',
  '/index.html',
  '/admin.html',
  '/repartidor.html',
  '/manifest.json',
  '/manifest-cliente.json',
  '/manifest-repartidor.json',
  '/app-config.js',
  '/icon-192.png',
  '/icon-512.png',
  '/icon-maskable-512.png',
  '/icon-180.png',
  '/favicon.ico'
];

const RUNTIME_HOSTS = ['fonts.googleapis.com', 'fonts.gstatic.com', 'cdn.jsdelivr.net'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(SHELL_CACHE)
      .then((cache) => Promise.all(SHELL.map((url) => cache.add(url).catch(() => null))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((key) => key !== SHELL_CACHE && key !== RUNTIME_CACHE).map((key) => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
});

function isRuntimeHost(url) {
  return RUNTIME_HOSTS.indexOf(url.hostname) !== -1;
}

function shellFor(pathname) {
  if (pathname.indexOf('/admin') === 0) return '/admin.html';
  if (pathname.indexOf('/repartidor') === 0) return '/repartidor.html';
  return OFFLINE_URL;
}

function offlineResponse() {
  return new Response(
    '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<title>Sin conexión</title><body style="font-family:system-ui,sans-serif;padding:40px;text-align:center">' +
    '<div style="font-size:48px">📡</div><h2>Sin conexión</h2>' +
    '<p>Vuelve a intentarlo cuando tengas internet.</p></body>',
    { status: 503, headers: { 'Content-Type': 'text/html; charset=utf-8' } }
  );
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  // Datos en vivo: siempre a la red.
  if (url.hostname.endsWith('.supabase.co')) return;

  // Navegación: red primero, luego copia cacheada, luego aviso de sin conexión.
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone();
          caches.open(RUNTIME_CACHE).then((cache) => cache.put(request, copy)).catch(() => {});
          return response;
        })
        .catch(async () => {
          const cached = await caches.match(request, { ignoreSearch: true });
          if (cached) return cached;
          const shell = await caches.match(shellFor(url.pathname));
          if (shell) return shell;
          return offlineResponse();
        })
    );
    return;
  }

  // Estáticos propios y CDNs permitidos: sirve de caché y revalida en segundo plano.
  if (url.origin === self.location.origin || isRuntimeHost(url)) {
    event.respondWith(
      caches.match(request).then((cached) => {
        const network = fetch(request)
          .then((response) => {
            if (response && (response.ok || response.type === 'opaque')) {
              const copy = response.clone();
              caches.open(RUNTIME_CACHE).then((cache) => cache.put(request, copy)).catch(() => {});
            }
            return response;
          })
          .catch(() => cached);
        return cached || network;
      })
    );
  }
});

self.addEventListener('push', function (event) {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (e) {
    payload = { body: event.data ? event.data.text() : '' };
  }

  const title = payload.title || '🔔 Nuevo pedido';
  const options = {
    body: payload.body || 'Tienes un nuevo pedido.',
    icon: payload.icon || '/icon-192.png',
    badge: '/icon-192.png',
    vibrate: [200, 100, 200, 100, 200],
    requireInteraction: true,
    renotify: true,
    tag: payload.tag || 'pedido',
    data: { url: payload.url || '/' }
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  const target = (event.notification.data && event.notification.data.url) || '/';
  const targetUrl = new URL(target, self.location.origin);

  event.waitUntil((async () => {
    const clientList = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of clientList) {
      const clientUrl = new URL(client.url);
      if (clientUrl.origin === targetUrl.origin && clientUrl.pathname === targetUrl.pathname && 'focus' in client) {
        return client.focus();
      }
    }
    if (self.clients.openWindow) return self.clients.openWindow(targetUrl.href);
  })());
});
