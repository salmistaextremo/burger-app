let webpush = null;
let webpushLoadError = null;
try {
  webpush = require('web-push');
} catch (e) {
  webpushLoadError = e;
}

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
  try {
    if (req.method !== 'POST') {
      return reply(res, 405, { error: 'Method not allowed' });
    }

    if (!PUSH_WEBHOOK_SECRET || req.headers['x-webhook-secret'] !== PUSH_WEBHOOK_SECRET) {
      return reply(res, 401, { error: 'Unauthorized' });
    }

    if (!webpush) {
      return reply(res, 500, { error: 'web-push no disponible', detail: webpushLoadError && webpushLoadError.message });
    }

    if (!VAPID_PUBLIC_KEY || !VAPID_PRIVATE_KEY || !VAPID_SUBJECT || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return reply(res, 500, { error: 'Faltan variables de entorno' });
    }

    try {
      webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);
    } catch (e) {
      return reply(res, 500, { error: 'VAPID inválido', detail: e && e.message });
    }

    let body = req.body;
    if (typeof body === 'string') {
      try { body = JSON.parse(body); } catch (e) { body = null; }
    }

    const envelope = body || {};
    const order = envelope.record || envelope;
    if (!order || !order.code) {
      return reply(res, 400, { error: 'Payload sin pedido' });
    }

    const event = String(envelope.type || envelope.event || 'INSERT').toUpperCase();
    const oldRecord = envelope.old_record || envelope.oldRecord || {};
    const customer = order.customer || {};
    const total = Number(order.total || 0).toFixed(2);
    const typeLabel = order.type === 'delivery' ? 'Delivery' : 'Retiro';

    let audience = 'admin';
    let title;
    let text;
    let url;
    let tag;

    if (event === 'UPDATE') {
      const status = String(order.status || '');
      if (status !== 'camino' && status !== 'listo') {
        return reply(res, 200, { skipped: 'status', status });
      }
      if (oldRecord && oldRecord.status === status) {
        return reply(res, 200, { skipped: 'same-status', status });
      }
      audience = 'repartidor';
      title = '🛵 Pedido ' + order.code + (status === 'camino' ? ' en camino' : ' listo');
      text = (customer.name || 'Cliente') + ' · ' + typeLabel + ' · $' + total;
      url = '/repartidor.html';
      tag = 'pedido-' + order.code + '-' + status;
    } else {
      title = '🔔 Nuevo pedido ' + order.code;
      text = (customer.name || 'Cliente') + ' · ' + typeLabel + ' · $' + total;
      url = '/admin.html';
      tag = 'pedido-' + order.code;
    }

    const base = SUPABASE_URL.replace(/\/$/, '');
    const headers = {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: 'Bearer ' + SUPABASE_SERVICE_ROLE_KEY,
      'Content-Type': 'application/json'
    };

    let subs = [];
    try {
      let r = await fetch(base + '/rest/v1/push_subscriptions?select=endpoint,p256dh,auth&role=eq.' + encodeURIComponent(audience), { headers });
      // Compatibilidad mientras no se ejecute la migración 10 (columna role)
      if (!r.ok && audience === 'admin') {
        r = await fetch(base + '/rest/v1/push_subscriptions?select=endpoint,p256dh,auth', { headers });
      }
      if (!r.ok) {
        const detail = await r.text();
        return reply(res, 502, { error: 'No se pudieron leer las suscripciones', status: r.status, detail: detail.slice(0, 300) });
      }
      subs = await r.json();
    } catch (e) {
      return reply(res, 502, { error: 'Error leyendo suscripciones', detail: e && e.message });
    }

    if (!Array.isArray(subs) || subs.length === 0) {
      return reply(res, 200, { sent: 0, total: 0, audience });
    }

    const payload = JSON.stringify({
      title,
      body: text,
      url,
      icon: '/icon-192.png',
      tag
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

    return reply(res, 200, { sent, total: subs.length, removed, audience });
  } catch (err) {
    return reply(res, 500, { error: 'Error interno', detail: err && err.message });
  }
};
