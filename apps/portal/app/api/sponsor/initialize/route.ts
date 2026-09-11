import { NextResponse } from 'next/server';

function normalizeNigerianPhone(phone: string): string {
  let cleaned = phone.trim().replace(/[\s-]/g, '');
  if (cleaned.startsWith('0')) {
    cleaned = '+234' + cleaned.substring(1);
  } else if (cleaned.startsWith('234')) {
    cleaned = '+' + cleaned;
  }
  return cleaned;
}

const PRICING_KOBO: Record<string, Record<string, number>> = {
  pro: {
    monthly: 4000 * 100,      // ₦4,000
    yearly: 36000 * 100,     // ₦36,000
  },
  family: {
    monthly: 13500 * 100,    // ₦13,500
    yearly: 120000 * 100,    // ₦120,000
  },
};

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { targetPhone, tier = 'pro', period = 'monthly', sponsorEmail, sponsorName } = body;

    if (!targetPhone) {
      return NextResponse.json({ error: 'Recipient phone number is required' }, { status: 400 });
    }
    if (!sponsorEmail) {
      return NextResponse.json({ error: 'Sponsor email is required for payment receipt' }, { status: 400 });
    }

    const normalizedPhone = normalizeNigerianPhone(targetPhone);
    if (!/^\+234[789][01]\d{8}$/.test(normalizedPhone)) {
      return NextResponse.json({ error: 'Invalid Nigerian phone number. Format should be e.g. +2348012345678 or 08012345678' }, { status: 400 });
    }

    const amountKobo = PRICING_KOBO[tier]?.[period];
    if (!amountKobo) {
      return NextResponse.json({ error: 'Invalid tier or billing period' }, { status: 400 });
    }

    const reference = `spn_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const paystackSecret = process.env.PAYSTACK_SECRET_KEY;
    const durationMonths = period === 'yearly' ? 12 : 1;
    const callbackUrl = process.env.NEXT_PUBLIC_PORTAL_URL
      ? `${process.env.NEXT_PUBLIC_PORTAL_URL}/sponsor/success?ref=${reference}&phone=${encodeURIComponent(normalizedPhone)}`
      : 'https://aura-safety.app/sponsor/success';

    const metadata = {
      flow_type: 'sponsorship',
      target_phone: normalizedPhone,
      tier,
      period,
      duration_months: durationMonths,
      sponsor_name: sponsorName || 'Anonymous Sponsor',
      sponsor_email: sponsorEmail,
    };

    if (!paystackSecret) {
      // Return simulated link in development when test secret key is not set
      console.warn('[DEV] PAYSTACK_SECRET_KEY not found. Returning mock payment initialization.');
      return NextResponse.json({
        authorization_url: `${callbackUrl}&mock=true`,
        reference,
        amount_kobo: amountKobo,
        simulated: true,
      });
    }

    const res = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${paystackSecret}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: sponsorEmail,
        amount: amountKobo,
        reference,
        currency: 'NGN',
        callback_url: callbackUrl,
        metadata,
      }),
    });

    const data = await res.json();
    if (!res.ok || !data.status) {
      return NextResponse.json({ error: data.message || 'Paystack initialization failed' }, { status: 400 });
    }

    return NextResponse.json({
      authorization_url: data.data.authorization_url,
      reference,
      access_code: data.data.access_code,
    });
  } catch (err) {
    console.error('Error initializing sponsorship payment:', err);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
