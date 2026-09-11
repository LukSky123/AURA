import Link from 'next/link';

type Props = {
  searchParams: Promise<{ ref?: string; phone?: string; mock?: string }>;
};

export default async function SponsorSuccessPage({ searchParams }: Props) {
  const params = await searchParams;
  const ref = params.ref || 'N/A';
  const phone = params.phone || 'the recipient';

  return (
    <main style={{ maxWidth: 540, margin: '60px auto', padding: '0 20px', textAlign: 'center', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <div style={{ width: 64, height: 64, backgroundColor: '#dcfce7', color: '#15803d', borderRadius: 999, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontSize: 32, marginBottom: 20 }}>
        ✓
      </div>
      <h1 style={{ fontSize: 26, fontWeight: 800, color: '#111827', margin: '0 0 12px' }}>
        Sponsorship Activated!
      </h1>
      <p style={{ color: '#4b5563', fontSize: 16, lineHeight: 1.5, margin: '0 0 24px' }}>
        Thank you for protecting your loved one. The AURA safety coverage has been provisioned for <strong>{phone}</strong>.
      </p>
      <div style={{ backgroundColor: '#f9fafb', border: '1px solid #e5e7eb', borderRadius: 12, padding: 16, textAlign: 'left', marginBottom: 28 }}>
        <div style={{ fontSize: 13, color: '#6b7280' }}>Reference Code</div>
        <div style={{ fontFamily: 'monospace', fontWeight: 600, color: '#111827', marginTop: 4 }}>{ref}</div>
      </div>
      <Link
        href="/"
        style={{ display: 'inline-block', backgroundColor: '#111827', color: '#ffffff', textDecoration: 'none', padding: '12px 24px', borderRadius: 8, fontWeight: 600, fontSize: 15 }}
      >
        Return to AURA Home
      </Link>
    </main>
  );
}
