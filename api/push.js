const webpush = require('web-push');

const {
  VAPID_PUBLIC_KEY,
  VAPID_PRIVATE_KEY,
  VAPID_SUBJECT,
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  PUSH_WEBHOOK_SECRET
} = process.env;

function reply(res, status, body) {
  res.status(status);
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify(body));
}

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return reply(res, 405, { error: 'Method not allowed' });
  }

  if (!PUSH_WEBHOOK_SECRET || req.headers['x-webhook-secret'] !== PUSH_WEBHOOK_SECRET) {
    return reply(res, 401, { error: 'Unauthorized' });
  }

  if (!VAPID_PUBLIC_KEY || !VAPID_PRIVATE_KEY || !VAPID_SUBJECT || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return reply(res, 500, { error: 'Faltan variables de entorno' });
  }

  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch (e) { body = null; }
  }

  const order = body && (body.record || body);
  if (!order || !order.code) {
    return reply(res, 400, { error: 'Payload sin pedido' });
  }

  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);

  const base = SUPABASE_URL.replace(/\/$/, '');
  const headers = {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    Authorization: 'Bearer ' + SUPABASE_SERVICE_ROLE_KEY,
    'Content-Type': 'application/json'
  };

  let subs = [];
  try {
    const r = await fetch(base + '/rest/v1/push_subscriptions?select=endpoint,p256dh,auth', { headers });
    if (!r.ok) {
      return reply(res, 502, { error: 'No se pudieron leer las suscripciones', status: r.status });
    }
    subs = await r.json();
  } catch (e) {
    return reply(res, 502, { error: 'Error leyendo suscripciones' });
  }

  if (!Array.isArray(subs) || subs.length === 0) {
    return reply(res, 200, { sent: 0, total: 0 });
  }

  const customer = order.customer || {};
  const total = Number(order.total || 0).toFixed(2);
  const type = order.type === 'delivery' ? 'Delivery' : 'Retiro';
  const payload = JSON.stringify({
    title: '🔔 Nuevo pedido ' + order.code,
    body: (customer.name || 'Cliente') + ' · ' + type + ' · $' + total,
    url: '/admin.html',
    icon: '/icon-192.png',
    tag: 'pedido-' + order.code
  });

  let sent = 0;
  let removed = 0;

  await Promise.all(subs.map(async (s) => {
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        payload,
        { TTL: 3600, urgency: 'high' }
      );
      sent++;
    } catch (err) {
      if (err && (err.statusCode === 404 || err.statusCode === 410)) {
        try {
          await fetch(base + '/rest/v1/push_subscriptions?endpoint=eq.' + encodeURIComponent(s.endpoint), {
            method: 'DELETE',
            headers
          });
          removed++;
        } catch (e) {}
      } else {
        console.warn('Push falló:', err && err.statusCode, err && err.body);
      }
    }
  }));

  return reply(res, 200, { sent, total: subs.length, removed });
};
