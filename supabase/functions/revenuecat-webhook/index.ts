import { admin, json } from '../_shared/auth.ts';

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const authKey = Deno.env.get('REVENUECAT_WEBHOOK_AUTH_KEY');
  const incomingAuth = request.headers.get('Authorization');

  if (authKey && incomingAuth !== authKey && incomingAuth !== `Bearer ${authKey}`) {
    console.error('Unauthorized RevenueCat webhook attempt');
    return json({ error: 'Unauthorized' }, 401);
  }

  let body: any;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'Malformed JSON' }, 400);
  }

  const event = body.event;
  if (!event) return json({ error: 'Missing event object' }, 400);

  const type = event.type;
  const appUserId = event.app_user_id; // Supabase user_id passed when configuring RevenueCat SDK
  const productId = event.product_id?.toLowerCase() || '';
  const expirationAtMs = event.expiration_at_ms;

  console.log(`Received RevenueCat event ${type} for user ${appUserId}, product ${productId}`);

  if (!appUserId) return json({ received: true });

  // Map product id to tier
  let tier: 'pro' | 'family' = 'pro';
  if (productId.includes('family')) {
    tier = 'family';
  }

  const periodEnd = expirationAtMs ? new Date(expirationAtMs).toISOString() : null;

  switch (type) {
    case 'INITIAL_PURCHASE':
    case 'RENEWAL':
    case 'PRODUCT_CHANGE':
    case 'UNCANCELLATION':
      await admin.from('subscriptions').insert({
        user_id: appUserId,
        tier,
        status: 'active',
        provider: 'revenuecat',
        provider_sub_id: event.original_transaction_id || event.transaction_id,
        current_period_start: new Date(event.purchased_at_ms || Date.now()).toISOString(),
        current_period_end: periodEnd,
      });
      break;

    case 'CANCELLATION':
      // User turned off auto-renew, remains active until current_period_end
      await admin.from('subscriptions')
        .update({ cancel_at_period_end: true })
        .eq('user_id', appUserId)
        .eq('status', 'active');
      break;

    case 'EXPIRATION':
      await admin.from('subscriptions')
        .update({ status: 'expired' })
        .eq('user_id', appUserId)
        .eq('status', 'active');
      break;

    default:
      console.log(`Unhandled RevenueCat event type: ${type}`);
  }

  return json({ received: true });
});
