import { admin, json, requireUser } from '../_shared/auth.ts';

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const user = await requireUser(request);
    const body = await request.json();
    const incidentId = body.incidentId;

    if (!incidentId) return json({ error: 'Missing incidentId' }, 400);

    const { data: incident } = await admin
      .from('incidents')
      .select('id')
      .eq('id', incidentId)
      .eq('owner_id', user.id)
      .maybeSingle();

    if (!incident) return json({ error: 'Incident not found' }, 404);

    type PointPayload = {
      latitude: number;
      longitude: number;
      accuracyM?: number;
      recordedAt?: string;
    };

    const points: PointPayload[] = Array.isArray(body.points)
      ? body.points
      : (typeof body.latitude === 'number' && typeof body.longitude === 'number')
        ? [{
            latitude: body.latitude,
            longitude: body.longitude,
            accuracyM: body.accuracyM,
            recordedAt: body.recordedAt,
          }]
        : [];

    if (points.length === 0) {
      return json({ error: 'No valid location points provided' }, 400);
    }

    let insertedCount = 0;
    for (const pt of points) {
      if (
        typeof pt.latitude !== 'number' ||
        typeof pt.longitude !== 'number' ||
        pt.latitude < -90 ||
        pt.latitude > 90 ||
        pt.longitude < -180 ||
        pt.longitude > 180
      ) {
        continue;
      }

      const { error } = await admin.rpc('insert_location_point', {
        p_incident_id: incidentId,
        p_longitude: pt.longitude,
        p_latitude: pt.latitude,
        p_accuracy_m: pt.accuracyM ?? null,
        p_recorded_at: pt.recordedAt ?? new Date().toISOString(),
      });

      if (!error) insertedCount++;
    }

    return json({ ok: true, insertedCount });
  } catch (error) { return json({ error: error instanceof Error ? error.message : 'Unauthorized' }, 401); }
});
