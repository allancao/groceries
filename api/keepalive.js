// Daily keep-alive: a lightweight request to Supabase so the free-tier
// project isn't auto-paused for inactivity. Invoked by the Vercel cron in
// vercel.json. Reads a single public row (list_invites is anon-readable).
module.exports = async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY;
  if (!url || !key) { res.status(500).json({ ok: false, error: 'missing supabase config' }); return; }
  try {
    const r = await fetch(`${url}/rest/v1/list_invites?select=id&limit=1`, {
      headers: { apikey: key, Authorization: `Bearer ${key}` }
    });
    res.status(200).json({ ok: true, status: r.status, at: new Date().toISOString() });
  } catch (e) {
    // Still 200 so the cron isn't marked failed; the request itself is what
    // keeps the project awake.
    res.status(200).json({ ok: false, error: String(e), at: new Date().toISOString() });
  }
};
