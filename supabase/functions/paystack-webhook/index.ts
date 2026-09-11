import { admin, json } from '../_shared/auth.ts';

// Verify Paystack HMAC-SHA512 signature
async function verifyPaystackSignature(signature: string | null, rawBody: string, secretKey: string): Promise<boolean> {
  if (!signature || !secretKey) return false;
  const keyData = new TextEncoder().encode(secretKey);
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-512' },
    false,
    ['sign']
  );
  const bodyData = new TextEncoder().encode(rawBody);
  const sigBuffer = await crypto.subtle.sign('HMAC', cryptoKey, bodyData);
  const hashArray = Array.from(new Uint8Array(sigBuffer));
  const expectedSignature = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  return signature === expectedSignature;
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const paystackSecret = Deno.env.get('PAYSTACK_SECRET_KEY') || '';
  const signature = request.headers.get('x-paystack-signature');
  const rawBody = await request.text();

  // In production, signature verification is required
  if (paystackSecret && !(await verifyPaystackSignature(signature, rawBody, paystackSecret))) {
    console.error('Invalid Paystack signature');
    return json({ error: 'Invalid signature' }, 401);
  }

  let eventData: any;
  try {
    eventData = JSON.parse(rawBody);
  } catch {
    return json({ error: 'Malformed JSON' }, 400);
  }

  const { event, data } = eventData;
  console.log(`Received Paystack event: ${event}, reference: ${data?.reference}`);

  if (event === 'charge.success') {
    const reference = data.reference;
    const amountKobo = data.amount;
    const metadata = data.metadata || {};
    const channel = data.channel;

    // Check if already processed
    const { data: existingTx } = await admin
      .from('payment_transactions')
      .select('id')
      .eq('reference', reference)
      .maybeSingle();

    if (existingTx) {
      return json({ status: 'already_processed' });
    }

    const flowType = metadata.flow_type || 'subscription'; // 'subscription' or 'sponsorship'
    const tier = metadata.tier === 'family' ? 'family' : 'pro';
    const durationMonths = parseInt(metadata.duration_months || '1', 10);

    if (flowType === 'sponsorship') {
      const targetPhone = metadata.target_phone;
      const sponsorEmail = data.customer?.email || metadata.sponsor_email;
      const sponsorName = metadata.sponsor_name || 'Anonymous Sponsor';

      // 1. Record Sponsorship
      const { data: sponsorRow, error: sponsorError } = await admin
        .from('sponsorships')
        .insert({
          sponsor_email: sponsorEmail,
          sponsor_name: sponsorName,
          target_phone_e164: targetPhone,
          tier,
          duration_months: durationMonths,
          payment_reference: reference,
        })
        .select()
        .single();

      if (sponsorError) {
        console.error('Failed to create sponsorship record:', sponsorError);
      }

      // 2. If user already exists by phone, activate immediately
      const { data: targetProfile } = await admin
        .from('profiles')
        .select('id')
        .eq('phone_e164', targetPhone)
        .maybeSingle();

      if (targetProfile && sponsorRow) {
        const periodEnd = new Date();
        periodEnd.setMonth(periodEnd.getMonth() + durationMonths);

        await admin.from('subscriptions').insert({
          user_id: targetProfile.id,
          tier,
          status: 'active',
          provider: 'sponsorship',
          provider_sub_id: reference,
          current_period_start: new Date().toISOString(),
          current_period_end: periodEnd.toISOString(),
        });

        await admin.from('sponsorships').update({
          applied_user_id: targetProfile.id,
          applied_at: new Date().toISOString(),
        }).eq('id', sponsorRow.id);
      }

      // 3. Record transaction
      await admin.from('payment_transactions').insert({
        user_id: targetProfile?.id || null,
        reference,
        amount_kobo: amountKobo,
        currency: 'NGN',
        channel,
        provider: 'paystack',
        status: 'success',
        metadata: { ...metadata, flow_type: 'sponsorship' },
      });

    } else {
      // Direct User Subscription
      const userId = metadata.user_id;
      if (userId) {
        const periodEnd = new Date();
        periodEnd.setMonth(periodEnd.getMonth() + durationMonths);

        // Upsert subscription
        await admin.from('subscriptions').insert({
          user_id: userId,
          tier,
          status: 'active',
          provider: 'paystack',
          provider_sub_id: reference,
          current_period_start: new Date().toISOString(),
          current_period_end: periodEnd.toISOString(),
        });

        await admin.from('payment_transactions').insert({
          user_id: userId,
          reference,
          amount_kobo: amountKobo,
          currency: 'NGN',
          channel,
          provider: 'paystack',
          status: 'success',
          metadata,
        });
      }
    }
  }

  return json({ received: true });
});
