import { admin, json, requireUser } from '../_shared/auth.ts';

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const user = await requireUser(request);
    const { incidentId, reason } = await request.json();

    if (!incidentId) {
      return json({ error: 'Missing incidentId' }, 400);
    }

    // Verify incident belongs to requesting user and update status
    const { data: incident, error } = await admin
      .from('incidents')
      .update({
        status: 'cancelled',
        resolved_at: new Date().toISOString(),
      })
      .eq('id', incidentId)
      .eq('owner_id', user.id)
      .select()
      .maybeSingle();

    if (error) throw error;
    if (!incident) return json({ error: 'Incident not found' }, 404);

    // Revoke all active contact links immediately so public tokens become inert
    await admin
      .from('incident_contact_links')
      .update({ revoked_at: new Date().toISOString() })
      .eq('incident_id', incidentId)
      .is('revoked_at', null);

    // Record cancellation event in timeline
    await admin.from('incident_events').insert({
      incident_id: incidentId,
      actor_user_id: user.id,
      event_type: 'cancelled',
      details: {
        reason: reason ?? 'false_alarm',
        cancelled_at: new Date().toISOString(),
      },
    });

    // Record in audit log
    await admin.from('audit_logs').insert({
      actor_id: user.id,
      action: 'incident_cancelled',
      entity_type: 'incident',
      entity_id: incidentId,
      metadata: { reason: reason ?? 'false_alarm' },
    });

    return json({
      ok: true,
      incident,
      status: 'cancelled',
    });
  } catch (error) {
    console.error('Error cancelling incident:', error);
    return json({ error: error instanceof Error ? error.message : 'Unauthorized' }, 401);
  }
});
