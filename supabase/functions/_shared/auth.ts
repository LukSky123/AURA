import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
export const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
export const admin = createClient(supabaseUrl, serviceRole, { auth: { persistSession: false } });

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

export async function requireUser(request: Request) {
  const token = request.headers.get('Authorization')?.replace('Bearer ', '');
  if (!token) throw new Error('Unauthorized');
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) throw new Error('Unauthorized');
  return data.user;
}
