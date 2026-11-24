const crypto = require('crypto');

const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env;

function reply(res, status, body) {
  res.status(status);
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Cache-Control', 'no-store');
  res.end(JSON.stringify(body));
}

module.exports = async (req, res) => {
  try {
    if (req.method !== 'POST') {
      return reply(res, 405, { error: 'Method not allowed' });
    }
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return reply(res, 500, { error: 'Faltan variables de entorno' });
    }

    let body = req.body;
    if (typeof body === 'string') {
      try { body = JSON.parse(body); } catch (e) { body = null; }
    }

    const code = String((body && body.code) || '').trim();
    let image = String((body && body.image) || '');
    if (!/^A-[A-Z0-9]{4,8}$/.test(code)) {
      return reply(res, 400, { error: 'Código inválido' });
    }

    image = image.replace(/^data:image\/png;base64,/, '');
    if (!image) return reply(res, 400, { error: 'Falta la imagen' });

    let buffer;
    try {
      buffer = Buffer.from(image, 'base64');
    } catch (e) {
      return reply(res, 400, { error: 'Imagen inválida' });
    }

    if (!buffer || buffer.length < 100 || buffer.length > 2 * 1024 * 1024) {
      return reply(res, 400, { error: 'Tamaño de imagen inválido' });
    }
    const pngSignature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    if (!buffer.subarray(0, 8).equals(pngSignature)) {
      return reply(res, 400, { error: 'Formato inválido' });
    }

    const base = SUPABASE_URL.replace(/\/$/, '');
    const serviceHeaders = {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: 'Bearer ' + SUPABASE_SERVICE_ROLE_KEY
    };

    // Solo permitir tickets de pedidos recientes (evita subidas anónimas sueltas)
    const since = new Date(Date.now() - 30 * 60 * 1000).toISOString();
    const checkUrl = base + '/rest/v1/orders?code=eq.' + encodeURIComponent(code) +
      '&created_at=gte.' + encodeURIComponent(since) + '&select=code&limit=1';
    const check = await fetch(checkUrl, { headers: serviceHeaders });
    if (!check.ok) {
      return reply(res, 502, { error: 'No se pudo verificar el pedido' });
    }
    const rows = await check.json();
    if (!Array.isArray(rows) || rows.length === 0) {
      return reply(res, 403, { error: 'Pedido no encontrado o demasiado antiguo' });
    }

    const path = code + '-' + Date.now() + '-' + crypto.randomBytes(4).toString('hex') + '.png';
    const upload = await fetch(base + '/storage/v1/object/tickets/' + encodeURIComponent(path), {
      method: 'POST',
      headers: {
        ...serviceHeaders,
        'Content-Type': 'image/png',
        'x-upsert': 'false'
      },
      body: buffer
    });
    if (!upload.ok) {
      const detail = await upload.text();
      return reply(res, 502, { error: 'No se pudo subir el ticket', detail: detail.slice(0, 300) });
    }

    const sign = await fetch(base + '/storage/v1/object/sign/tickets/' + encodeURIComponent(path), {
      method: 'POST',
      headers: { ...serviceHeaders, 'Content-Type': 'application/json' },
      body: JSON.stringify({ expiresIn: 604800 })
    });
    if (!sign.ok) {
      const detail = await sign.text();
      return reply(res, 502, { error: 'No se pudo firmar el ticket', detail: detail.slice(0, 300) });
    }

    const signed = await sign.json();
    if (!signed || !signed.signedURL) {
      return reply(res, 502, { error: 'Sin URL firmada' });
    }

    const url = signed.signedURL.startsWith('http')
      ? signed.signedURL
      : base + '/storage/v1' + signed.signedURL;

    return reply(res, 200, { url: url });
  } catch (err) {
    return reply(res, 500, { error: 'Error interno', detail: err && err.message });
  }
};
