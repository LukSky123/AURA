'use client';

import React, { useState } from 'react';

export default function SponsorPage() {
  const [tier, setTier] = useState<'pro' | 'family'>('pro');
  const [period, setPeriod] = useState<'monthly' | 'yearly'>('monthly');
  const [targetPhone, setTargetPhone] = useState('');
  const [sponsorName, setSponsorName] = useState('');
  const [sponsorEmail, setSponsorEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');

  const pricing = {
    pro: { monthly: '₦4,000 / month', yearly: '₦36,000 / year (Save 25%)' },
    family: { monthly: '₦13,500 / month', yearly: '₦120,000 / year (Save 25%)' },
  };

  async function handleSponsorSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setErrorMessage('');

    try {
      const res = await fetch('/api/sponsor/initialize', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          tier,
          period,
          targetPhone,
          sponsorName,
          sponsorEmail,
        }),
      });

      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.error || 'Failed to initialize payment.');
      }

      if (data.authorization_url) {
        window.location.href = data.authorization_url;
      } else {
        throw new Error('No payment URL returned from provider.');
      }
    } catch (err: any) {
      setErrorMessage(err.message || 'An unexpected error occurred.');
      setLoading(false);
    }
  }

  return (
    <main style={{ maxWidth: 640, margin: '40px auto', padding: '0 20px', fontFamily: 'system-ui, -apple-system, sans-serif', color: '#111827' }}>
      <header style={{ textAlign: 'center', marginBottom: 32 }}>
        <div style={{ display: 'inline-block', backgroundColor: '#fee2e2', color: '#b91c1c', padding: '6px 14px', borderRadius: 999, fontSize: 13, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 12 }}>
          Protect a Loved One
        </div>
        <h1 style={{ fontSize: 28, fontWeight: 800, margin: '8px 0 12px', color: '#111827' }}>
          Sponsor an AURA Safety Plan
        </h1>
        <p style={{ color: '#4b5563', fontSize: 16, lineHeight: 1.5, margin: 0 }}>
          Ensure family members and loved ones in Nigeria are protected 24/7 with on-device acoustic danger detection and automated emergency cloud SMS dispatch.
        </p>
      </header>

      {errorMessage && (
        <div style={{ backgroundColor: '#fef2f2', border: '1px solid #f87171', color: '#991b1b', padding: '12px 16px', borderRadius: 8, marginBottom: 24, fontSize: 14 }}>
          {errorMessage}
        </div>
      )}

      <form onSubmit={handleSponsorSubmit} style={{ backgroundColor: '#ffffff', border: '1px solid #e5e7eb', borderRadius: 16, padding: 24, boxShadow: '0 4px 6px -1px rgba(0,0,0,0.05)' }}>
        {/* Tier selection */}
        <section style={{ marginBottom: 24 }}>
          <label style={{ display: 'block', fontSize: 14, fontWeight: 600, color: '#374151', marginBottom: 10 }}>
            Select Protection Plan
          </label>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <button
              type="button"
              onClick={() => setTier('pro')}
              style={{
                textAlign: 'left',
                padding: 16,
                borderRadius: 12,
                border: tier === 'pro' ? '2px solid #b91c1c' : '1px solid #d1d5db',
                backgroundColor: tier === 'pro' ? '#fff1f2' : '#ffffff',
                cursor: 'pointer',
              }}
            >
              <div style={{ fontWeight: 700, fontSize: 16, color: '#111827' }}>AURA Pro</div>
              <div style={{ fontSize: 13, color: '#4b5563', marginTop: 4 }}>5 contacts, unlimited Termii SMS, safety routing</div>
              <div style={{ marginTop: 8, fontWeight: 700, color: '#b91c1c', fontSize: 14 }}>
                {pricing.pro[period]}
              </div>
            </button>

            <button
              type="button"
              onClick={() => setTier('family')}
              style={{
                textAlign: 'left',
                padding: 16,
                borderRadius: 12,
                border: tier === 'family' ? '2px solid #b91c1c' : '1px solid #d1d5db',
                backgroundColor: tier === 'family' ? '#fff1f2' : '#ffffff',
                cursor: 'pointer',
              }}
            >
              <div style={{ fontWeight: 700, fontSize: 16, color: '#111827' }}>AURA Family</div>
              <div style={{ fontSize: 13, color: '#4b5563', marginTop: 4 }}>Covers up to 5 accounts, circle sirens</div>
              <div style={{ marginTop: 8, fontWeight: 700, color: '#b91c1c', fontSize: 14 }}>
                {pricing.family[period]}
              </div>
            </button>
          </div>
        </section>

        {/* Billing period toggle */}
        <section style={{ marginBottom: 24 }}>
          <label style={{ display: 'block', fontSize: 14, fontWeight: 600, color: '#374151', marginBottom: 8 }}>
            Billing Frequency
          </label>
          <div style={{ display: 'inline-flex', backgroundColor: '#f3f4f6', borderRadius: 8, padding: 4 }}>
            <button
              type="button"
              onClick={() => setPeriod('monthly')}
              style={{
                padding: '6px 16px',
                borderRadius: 6,
                border: 'none',
                backgroundColor: period === 'monthly' ? '#ffffff' : 'transparent',
                fontWeight: 600,
                fontSize: 14,
                boxShadow: period === 'monthly' ? '0 1px 2px rgba(0,0,0,0.1)' : 'none',
                cursor: 'pointer',
              }}
            >
              Monthly
            </button>
            <button
              type="button"
              onClick={() => setPeriod('yearly')}
              style={{
                padding: '6px 16px',
                borderRadius: 6,
                border: 'none',
                backgroundColor: period === 'yearly' ? '#ffffff' : 'transparent',
                fontWeight: 600,
                fontSize: 14,
                boxShadow: period === 'yearly' ? '0 1px 2px rgba(0,0,0,0.1)' : 'none',
                cursor: 'pointer',
              }}
            >
              Annual (Save 25%)
            </button>
          </div>
        </section>

        {/* Recipient phone */}
        <section style={{ marginBottom: 20 }}>
          <label htmlFor="targetPhone" style={{ display: 'block', fontSize: 14, fontWeight: 600, color: '#374151', marginBottom: 6 }}>
            Recipient's Nigerian Phone Number
          </label>
          <input
            id="targetPhone"
            type="tel"
            required
            placeholder="e.g. 08012345678 or +2348012345678"
            value={targetPhone}
            onChange={(e) => setTargetPhone(e.target.value)}
            style={{ width: '100%', padding: '10px 14px', borderRadius: 8, border: '1px solid #d1d5db', fontSize: 15, boxSizing: 'border-box' }}
          />
          <span style={{ fontSize: 12, color: '#6b7280', marginTop: 4, display: 'block' }}>
            Coverage activates automatically on this phone number as soon as payment is confirmed.
          </span>
        </section>

        {/* Sponsor details */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 24 }}>
          <div>
            <label htmlFor="sponsorName" style={{ display: 'block', fontSize: 14, fontWeight: 600, color: '#374151', marginBottom: 6 }}>
              Your Name
            </label>
            <input
              id="sponsorName"
              type="text"
              required
              placeholder="e.g. Emeka Okafor"
              value={sponsorName}
              onChange={(e) => setSponsorName(e.target.value)}
              style={{ width: '100%', padding: '10px 14px', borderRadius: 8, border: '1px solid #d1d5db', fontSize: 15, boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label htmlFor="sponsorEmail" style={{ display: 'block', fontSize: 14, fontWeight: 600, color: '#374151', marginBottom: 6 }}>
              Your Email (for receipt)
            </label>
            <input
              id="sponsorEmail"
              type="email"
              required
              placeholder="e.g. emeka@example.com"
              value={sponsorEmail}
              onChange={(e) => setSponsorEmail(e.target.value)}
              style={{ width: '100%', padding: '10px 14px', borderRadius: 8, border: '1px solid #d1d5db', fontSize: 15, boxSizing: 'border-box' }}
            />
          </div>
        </div>

        <button
          type="submit"
          disabled={loading}
          style={{
            width: '100%',
            backgroundColor: loading ? '#9ca3af' : '#b91c1c',
            color: '#ffffff',
            padding: '14px 20px',
            borderRadius: 10,
            fontSize: 16,
            fontWeight: 700,
            border: 'none',
            cursor: loading ? 'not-allowed' : 'pointer',
            transition: 'background-color 0.15s ease',
          }}
        >
          {loading ? 'Initializing Secure Checkout…' : `Proceed to Paystack (${tier === 'pro' ? pricing.pro[period].split(' ')[0] : pricing.family[period].split(' ')[0]})`}
        </button>

        <div style={{ textAlign: 'center', marginTop: 14, fontSize: 12, color: '#6b7280' }}>
          🔒 Secured via Paystack. Supports Nigerian Cards, Bank Transfer, USSD, Apple Pay & Diaspora Cards.
        </div>
      </form>
    </main>
  );
}
