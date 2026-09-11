import { admin } from './auth.ts';

export type SubscriptionTier = 'free' | 'pro' | 'family';

export interface UserEntitlements {
  tier: SubscriptionTier;
  contactLimit: number;
  canSendCloudSms: boolean;
  remainingCloudSmsCredits: number;
}

export async function getUserEntitlements(userId: string): Promise<UserEntitlements> {
  const { data: tierData, error: tierError } = await admin.rpc('get_effective_user_tier', { p_user_id: userId });
  if (tierError) throw tierError;
  const tier = (tierData as SubscriptionTier) || 'free';

  const { data: allowanceData, error: allowanceError } = await admin.rpc('check_cloud_sms_allowance', { p_user_id: userId });
  if (allowanceError) throw allowanceError;

  const allowance = allowanceData?.[0] ?? {
    can_send_cloud_sms: false,
    remaining_credits: 0,
    current_tier: tier,
  };

  const contactLimit = tier === 'free' ? 2 : 5;

  return {
    tier,
    contactLimit,
    canSendCloudSms: allowance.can_send_cloud_sms,
    remainingCloudSmsCredits: allowance.remaining_credits,
  };
}

export async function recordSmsUsage(userId: string, incidentId: string): Promise<void> {
  const { error } = await admin.rpc('record_cloud_sms_usage', {
    p_user_id: userId,
    p_incident_id: incidentId,
  });
  if (error) {
    console.error(`Failed to record SMS usage for user ${userId}:`, error);
  }
}
