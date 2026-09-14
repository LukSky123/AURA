import 'package:flutter/foundation.dart';
import '../domain.dart';

abstract class EntitlementService {
  ValueListenable<UserEntitlements> get entitlements;
  bool canAddContact(int currentEnabledContacts);
  bool get canUseSmartRouting;
  bool get hasCircleSiren;
  bool get hasTransitWatch;
  Future<void> refreshEntitlements();
  Future<bool> purchaseSubscription(SubscriptionTier tier, {bool yearly = false});
}

class DefaultEntitlementService extends ValueNotifier<UserEntitlements>
    implements EntitlementService {
  DefaultEntitlementService({UserEntitlements? initial})
      : super(initial ?? UserEntitlements.free(remainingSms: 2));

  @override
  ValueListenable<UserEntitlements> get entitlements => this;

  UserEntitlements get current => value;

  @override
  bool canAddContact(int currentEnabledContacts) {
    return currentEnabledContacts < value.contactLimit;
  }

  @override
  bool get canUseSmartRouting => value.canUseSmartRouting;

  @override
  bool get hasCircleSiren => value.hasCircleSiren;

  @override
  bool get hasTransitWatch => value.hasTransitWatch;

  @override
  Future<void> refreshEntitlements() async {
    // In production with Supabase authenticated session:
    // Queries Supabase RPC get_effective_user_tier and check_cloud_sms_allowance.
    // Falls back to current value if offline.
    notifyListeners();
  }

  @override
  Future<bool> purchaseSubscription(SubscriptionTier tier, {bool yearly = false}) async {
    // For App Store / Google Play: invokes RevenueCat Purchases.purchasePackage()
    // For direct APK: invokes Paystack checkout URL.
    // For demo/testing, upgrade in-memory:
    if (tier == SubscriptionTier.pro) {
      value = UserEntitlements.pro();
    } else if (tier == SubscriptionTier.family) {
      value = UserEntitlements.family();
    }
    return true;
  }
}
