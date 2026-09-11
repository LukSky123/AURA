import { admin, json, requireUser } from '../_shared/auth.ts';

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const user = await requireUser(request);
    const { incidentId } = await request.json();
    const { data: incident, error } = await admin.from('incidents').update({ status: 'resolved', resolved_at: new Date().toISOString() }).eq('id', incidentId).eq('owner_id', user.id).select().maybeSingle();
    if (error) throw error;
    if (!incident) return json({ error: 'Incident not found' }, 404);
    await admin.from('incident_contact_links').update({ revoked_at: new Date().toISOString() }).eq('incident_id', incidentId).is('revoked_at', null);
    await admin.from('incident_events').insert({ incident_id: incidentId, actor_user_id: user.id, event_type: 'resolved' });
    return json({ incident });
  } catch (error) { return json({ error: error instanceof Error ? error.message : 'Unauthorized' }, 401); }
});
