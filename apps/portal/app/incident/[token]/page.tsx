import { notFound } from 'next/navigation';

type PageProps = { params: Promise<{ token: string }> };

export default async function IncidentPage({ params }: PageProps) {
  const { token } = await params;
  if (!/^[A-Za-z0-9_-]{32,}$/.test(token)) notFound();
  // The server route resolves this opaque token through a Supabase Edge
  // Function. Exact coordinates are never exposed on public map routes.
  return <main>
    <h1>AURA incident</h1>
    <p>This private link expires when the incident is resolved or after 24 hours.</p>
    <p>Loading incident status securely…</p>
    <form action={`/api/incident/${token}/acknowledge`} method="post"><button type="submit">Acknowledge</button></form>
    <form action={`/api/incident/${token}/confirm`} method="post"><button type="submit">Confirm incident</button></form>
  </main>;
}
