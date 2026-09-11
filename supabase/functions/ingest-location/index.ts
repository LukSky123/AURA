import { admin, json, requireUser } from '../_shared/auth.ts';

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const user = await requireUser(request);
    const { incidentId, latitude, longitude, accuracyM, recordedAt } = await request.json();
    if (![latitude, longitude].every((n) => typeof n === 'number') || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return json({ error: 'Invalid location' }, 400);
    const { data: incident } = await admin.from('incidents').select('id').eq('id', incidentId).eq('owner_id', user.id).maybeSingle();
    if (!incident) return json({ error: 'Incident not found' }, 404);
    const { error } = await admin.rpc('insert_location_point', { p_incident_id: incidentId, p_longitude: longitude, p_latitude: latitude, p_accuracy_m: accuracyM ?? null, p_recorded_at: recordedAt ?? new Date().toISOString() });
    if (error) throw error;
    return json({ ok: true });
  } catch (error) { return json({ error: error instanceof Error ? error.message : 'Unauthorized' }, 401); }
});
