export interface SendSmsOptions {
  to: string;
  message: string;
}

export async function sendTermiiSms(options: SendSmsOptions): Promise<{ success: boolean; id?: string; error?: string }> {
  const apiKey = Deno.env.get('TERMII_API_KEY');
  const senderId = Deno.env.get('TERMII_SENDER_ID') || 'AURA';

  if (!apiKey) {
    console.warn(`[DEV/MOCK] Termii API Key not configured. Simulating SMS to ${options.to}: "${options.message}"`);
    return { success: true, id: `mock-${Date.now()}` };
  }

  try {
    const response = await fetch('https://api.ng.termii.com/api/sms/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        to: options.to,
        from: senderId,
        sms: options.message,
        type: 'plain',
        channel: 'generic',
        api_key: apiKey,
      }),
    });

    const data = await response.json();
    if (!response.ok || (data.code && data.code !== 'ok')) {
      console.error('Termii API error response:', data);
      return { success: false, error: data.message || 'Termii delivery failed' };
    }

    return { success: true, id: data.message_id };
  } catch (err) {
    console.error('Network error calling Termii:', err);
    return { success: false, error: err instanceof Error ? err.message : 'Network error' };
  }
}
