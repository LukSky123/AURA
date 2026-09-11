import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'AURA Incident', robots: { index: false, follow: false } };
export default function Layout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body style={{ fontFamily: 'system-ui', maxWidth: 720, margin: '0 auto', padding: 24 }}>{children}</body></html>; }
