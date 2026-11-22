module.exports = (req, res) => {
  const secret = process.env.PUSH_WEBHOOK_SECRET || '';
  const service = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
  res.status(200);
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({
    ok: true,
    vercelEnv: process.env.VERCEL_ENV || null,
    branch: process.env.VERCEL_GIT_COMMIT_REF || null,
    pushSecret: !!secret,
    pushSecretLength: secret.length,
    serviceRole: !!service,
    serviceRoleLength: service.length,
    supabaseUrl: !!process.env.SUPABASE_URL,
    vapidPublic: !!process.env.VAPID_PUBLIC_KEY,
    vapidPrivate: !!process.env.VAPID_PRIVATE_KEY,
    vapidSubject: !!process.env.VAPID_SUBJECT,
    vercelUrl: process.env.VERCEL_URL || null,
    commit: process.env.VERCEL_GIT_COMMIT_SHA || null
  }));
};
