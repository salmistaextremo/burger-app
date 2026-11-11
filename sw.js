// sw.js
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim());
});

// Evento Fetch necesario para que sea instalable
self.addEventListener('fetch', (event) => {
  // Dejar vacío
});

self.addEventListener('push', function(event) {
  const options = {
    body: event.data ? event.data.text() : '¡Tienes un nuevo pedido!',
    icon: '/icon-512.png',
    badge: '/icon-512.png',
    vibrate: [200, 100, 200, 100, 200, 100, 200],
    requireInteraction: true,
    renotify: true,
    silent: false,
    data: { url: '/' } // URL por defecto
  };

  event.waitUntil(
    self.registration.showNotification('🔔 Notificación', options)
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  
  // Si la notificación trae una URL específica, la usamos. Si no, abre el index.
  const urlToOpen = event.notification.data && event.notification.data.url ? event.notification.data.url : '/';
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      // Si ya hay una pestaña abierta de la app, la enfoca
      for (let i = 0; i < clientList.length; i++) {
        let client = clientList[i];
        if (client.url.includes(urlToOpen) && 'focus' in client) {
          return client.focus();
        }
      }
      // Si no, abre una nueva ventana
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});
