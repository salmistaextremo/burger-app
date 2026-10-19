// sw.js
self.addEventListener('push', function(event) {
  const options = {
    body: event.data ? event.data.text() : '¡Tienes un nuevo pedido!',
    icon: 'https://cdn-icons-png.flaticon.com/512/3075/3075977.png',
    badge: 'https://cdn-icons-png.flaticon.com/512/3075/3075977.png',
    vibrate: [200, 100, 200, 100, 200, 100, 200],
    requireInteraction: true,
    renotify: true,
    silent: false,
    data: {
      url: '/admin.html'
    }
  };

  event.waitUntil(
    self.registration.showNotification('🔔 ¡Nuevo Pedido Recibido!', options)
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      // Busca si ya hay una pestaña del admin abierta
      for (let i = 0; i < clientList.length; i++) {
        let client = clientList[i];
        if (client.url.includes('/admin.html') && 'focus' in client) {
          return client.focus();
        }
      }
      // Si no, abre una nueva
      if (clients.openWindow) {
        return clients.openWindow('/admin.html');
      }
    })
  );
});
