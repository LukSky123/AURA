import { admin, json } from '../_shared/auth.ts';

const hash = async (value: string) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)))).map((b) => b.toString(16).padStart(2, '0')).join('');

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const { token, action } = await request.json();
  if (typeof token !== 'string' || !['acknowledge', 'confirm'].includes(action)) return json({ error: 'Invalid request' }, 400);
  const { data: link } = await admin.from('incident_contact_links').select('incident_id, contact_id, expires_at, revoked_at').eq('token_hash', await hash(token)).maybeSingle();
  if (!link || link.revoked_at || new Date(link.expires_at) < new Date()) return json({ error: 'Link expired' }, 410);
  await admin.from('contact_actions').insert({ incident_id: link.incident_id, contact_id: link.contact_id, action: action === 'acknowledge' ? 'acknowledged' : 'confirmed' });
  if (action === 'confirm') await admin.from('incidents').update({ confirmed_for_routing: true }).eq('id', link.incident_id);
  if (action === 'acknowledge') await admin.from('incidents').update({ status: 'acknowledged' }).eq('id', link.incident_id).eq('status', 'dispatched');
  await admin.from('incident_events').insert({ incident_id: link.incident_id, event_type: `contact_${action}` });
  return json({ ok: true });
});
