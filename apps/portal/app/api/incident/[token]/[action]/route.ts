import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest, context: { params: Promise<{ token: string; action: string }> }) {
  const { token, action } = await context.params;
  if (!['acknowledge', 'confirm'].includes(action) || !/^[A-Za-z0-9_-]{32,}$/.test(token)) return NextResponse.json({ error: 'Invalid request' }, { status: 400 });
  const endpoint = process.env.SUPABASE_URL;
  if (!endpoint) return NextResponse.json({ error: 'Service not configured' }, { status: 503 });
  const response = await fetch(`${endpoint}/functions/v1/contact-action`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${process.env.SUPABASE_ANON_KEY ?? ''}` }, body: JSON.stringify({ token, action }) });
  return NextResponse.redirect(new URL(`/incident/${token}`, request.url), { status: response.ok ? 303 : 302 });
}
