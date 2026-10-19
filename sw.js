// sw.js
self.addEventListener('push', function(event) {
  const options = {
    body: event.data ? event.data.text() : '¡Tienes un nuevo pedido!',
    icon: 'https://cdn-icons-png.flaticon.com/512/3075/3075977.png', // Cambia por tu logo
    badge: 'https://cdn-icons-png.flaticon.com/512/3075/3075977.png',
    vibrate: [200, 100, 200, 100, 200, 100, 200], // Patrón de vibración insistente
    requireInteraction: true, // La notificación no se cierra sola hasta que el usuario interactúe
    renotify: true, // Vuelve a vibrar/sonar si se reemplaza una notificación anterior
    silent: false, // Permite que el sistema reproduzca el sonido por defecto
    data: {
      url: '/admin.html' // URL a abrir al hacer clic
    }
  };

  event.waitUntil(
    self.registration.showNotification('🔔 ¡Nuevo Pedido Recibido!', options)
  );
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close(); // Cierra la notificación
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then(function(clientList) {
      // Si ya hay una pestaña abierta con la app, la enfoca
      for (let i = 0; i < clientList.length; i++) {
        let client = clientList[i];
        if (client.url === '/' && 'focus' in client) {
          return client.focus();
        }
      }
      // Si no, abre una nueva ventana
      if (clients.openWindow) {
        return clients.openWindow(event.notification.data.url);
      }
    })
  );
});
