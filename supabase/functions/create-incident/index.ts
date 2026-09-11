import { admin, json, requireUser } from '../_shared/auth.ts';
import { getUserEntitlements, recordSmsUsage } from '../_shared/entitlements.ts';
import { sendTermiiSms } from '../_shared/termii.ts';

const permittedKinds = new Set(['gunshot', 'glass_break', 'collision', 'explosion', 'manual_sos']);

async function hashToken(rawToken: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(rawToken);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  try {
    const user = await requireUser(request);
    const payload = await request.json();

    if (!permittedKinds.has(payload.kind)) return json({ error: 'Invalid incident kind' }, 400);
    if (payload.confidence != null && (typeof payload.confidence !== 'number' || payload.confidence < 0 || payload.confidence > 1)) {
      return json({ error: 'Invalid confidence' }, 400);
    }

    // 1. Resolve tier and contact limit
    const entitlements = await getUserEntitlements(user.id);
    const { data: contacts } = await admin
      .from('trusted_contacts')
      .select('id, display_name, phone_e164')
      .eq('owner_id', user.id)
      .eq('enabled', true)
      .limit(entitlements.contactLimit + 1);

    const activeContacts = (contacts ?? []).slice(0, entitlements.contactLimit);

    // 2. Create the incident
    const { data: incident, error: incidentError } = await admin.from('incidents').insert({
      owner_id: user.id,
      device_id: payload.deviceId ?? null,
      kind: payload.kind,
      confidence: payload.confidence ?? null,
      model_version: payload.modelVersion ?? null,
      status: 'dispatched',
      dispatched_at: new Date().toISOString(),
    }).select().single();

    if (incidentError) throw incidentError;

    // 3. Record event & audit log
    await admin.from('incident_events').insert({
      incident_id: incident.id,
      actor_user_id: user.id,
      event_type: 'dispatched',
      details: { channel: payload.channel ?? 'cloud', tier: entitlements.tier },
    });

    await admin.from('audit_logs').insert({
      actor_id: user.id,
      action: 'incident_created',
      entity_type: 'incident',
      entity_id: incident.id,
    });

    // 4. Generate contact tokens and links
    const portalBaseUrl = Deno.env.get('PORTAL_BASE_URL') || 'https://aura-safety.app';
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
    const contactLinks: { contactId: string; phone: string; name: string; link: string }[] = [];

    for (const contact of activeContacts) {
      // 32-char secure token
      const rawToken = crypto.randomUUID().replace(/-/g, '') + crypto.randomUUID().replace(/-/g, '').slice(0, 16);
      const tokenHash = await hashToken(rawToken);

      await admin.from('incident_contact_links').insert({
        incident_id: incident.id,
        contact_id: contact.id,
        token_hash: tokenHash,
        expires_at: expiresAt,
      });

      contactLinks.push({
        contactId: contact.id,
        phone: contact.phone_e164,
        name: contact.display_name,
        link: `${portalBaseUrl}/incident/${rawToken}`,
      });
    }

    // 5. SMS Dispatch Guard: Cloud Termii vs Local-SIM Fallback
    if (entitlements.canSendCloudSms) {
      // Cloud SMS authorized (Pro, Family, or Free with remaining quota)
      for (const item of contactLinks) {
        const message = `EMERGENCY ALERT from AURA: ${payload.kind.replace('_', ' ').toUpperCase()} detected! View live location & status: ${item.link}`;
        await sendTermiiSms({
          to: item.phone,
          message,
        });
      }

      await recordSmsUsage(user.id, incident.id);

      return json({
        incident,
        sms_dispatch_mode: 'cloud_termii',
        tier: entitlements.tier,
        remaining_cloud_sms_credits: entitlements.tier === 'free'
          ? Math.max(0, entitlements.remainingCloudSmsCredits - 1)
          : 'unlimited',
        notified_contacts_count: contactLinks.length,
      });
    } else {
      // Free tier monthly quota exhausted: guard Termii balance by falling back to device local-SIM SMS
      return json({
        incident,
        sms_dispatch_mode: 'fallback_to_local_sim',
        tier: entitlements.tier,
        reason: 'Monthly free cloud SMS quota exhausted (2/2 used). Direct local-SIM fallback activated.',
        fallback_targets: contactLinks.map(c => ({
          phone: c.phone,
          message: `EMERGENCY ALERT: ${payload.kind.replace('_', ' ').toUpperCase()} detected! View my location: ${c.link}`,
        })),
      });
    }
  } catch (error) {
    console.error('Error in create-incident:', error);
    return json({ error: error instanceof Error ? error.message : 'Unexpected error' }, 400);
  }
});
