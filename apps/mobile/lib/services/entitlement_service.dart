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

class DefaultEntitlementService extends ChangeNotifier implements EntitlementService {
  DefaultEntitlementService({UserEntitlements? initial})
      : _current = initial ?? UserEntitlements.free(remainingSms: 2);

  UserEntitlements _current;

  @override
  ValueListenable<UserEntitlements> get entitlements => this;

  UserEntitlements get current => _current;

  @override
  bool canAddContact(int currentEnabledContacts) {
    return currentEnabledContacts < _current.contactLimit;
  }

  @override
  bool get canUseSmartRouting => _current.canUseSmartRouting;

  @override
  bool get hasCircleSiren => _current.hasCircleSiren;

  @override
  bool get hasTransitWatch => _current.hasTransitWatch;

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
      _current = UserEntitlements.pro();
    } else if (tier == SubscriptionTier.family) {
      _current = UserEntitlements.family();
    }
    notifyListeners();
    return true;
  }

  @override
  UserEntitlements get value => _current;
}
