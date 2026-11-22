module.exports = (req, res) => {
  const secret = process.env.PUSH_WEBHOOK_SECRET || '';
  const service = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
  const pub = process.env.VAPID_PUBLIC_KEY || '';
  const priv = process.env.VAPID_PRIVATE_KEY || '';
  const subject = process.env.VAPID_SUBJECT || '';
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
    vapidPublic: !!pub,
    vapidPublicLength: pub.length,
    vapidPrivate: !!priv,
    vapidPrivateLength: priv.length,
    vapidSubject: !!subject,
    vapidSubjectLength: subject.length,
    vercelUrl: process.env.VERCEL_URL || null,
    commit: process.env.VERCEL_GIT_COMMIT_SHA || null
  }));
};
