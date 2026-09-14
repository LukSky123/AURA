enum IncidentKind { gunshot, glassBreak, collision, explosion, manualSos }

enum IncidentStatus { countdown, dispatched, acknowledged, resolved, cancelled }

enum SubscriptionTier { free, pro, family }

enum SmsDispatchMode { cloudTermii, fallbackToLocalSim }

class FallbackSmsTarget {
  const FallbackSmsTarget({
    required this.phone,
    required this.message,
  });
  final String phone;
  final String message;
}

class UserEntitlements {
  const UserEntitlements({
    required this.tier,
    required this.contactLimit,
    required this.canSendCloudSms,
    required this.remainingCloudSmsCredits,
    required this.canUseSmartRouting,
    required this.hasCircleSiren,
    required this.hasTransitWatch,
  });

  final SubscriptionTier tier;
  final int contactLimit;
  final bool canSendCloudSms;
  final int remainingCloudSmsCredits;
  final bool canUseSmartRouting;
  final bool hasCircleSiren;
  final bool hasTransitWatch;

  factory UserEntitlements.free({int remainingSms = 2}) => UserEntitlements(
    tier: SubscriptionTier.free,
    contactLimit: 2,
    canSendCloudSms: remainingSms > 0,
    remainingCloudSmsCredits: remainingSms,
    canUseSmartRouting: false,
    hasCircleSiren: false,
    hasTransitWatch: false,
  );

  factory UserEntitlements.pro() => const UserEntitlements(
    tier: SubscriptionTier.pro,
    contactLimit: 5,
    canSendCloudSms: true,
    remainingCloudSmsCredits: 999999,
    canUseSmartRouting: true,
    hasCircleSiren: false,
    hasTransitWatch: true,
  );

  factory UserEntitlements.family() => const UserEntitlements(
    tier: SubscriptionTier.family,
    contactLimit: 5,
    canSendCloudSms: true,
    remainingCloudSmsCredits: 999999,
    canUseSmartRouting: true,
    hasCircleSiren: true,
    hasTransitWatch: true,
  );
}

class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    this.enabled = true,
  });
  final String id;
  final String name;
  final String phone;
  final bool enabled;
}

class Incident {
  const Incident({
    required this.id,
    required this.kind,
    required this.status,
    required this.createdAt,
    this.confidence,
    this.smsDispatchMode,
    this.fallbackTargets = const [],
    this.latitude,
    this.longitude,
  });
  final String id;
  final IncidentKind kind;
  final IncidentStatus status;
  final DateTime createdAt;
  final double? confidence;
  final SmsDispatchMode? smsDispatchMode;
  final List<FallbackSmsTarget> fallbackTargets;
  final double? latitude;
  final double? longitude;

  Incident copyWith({
    IncidentStatus? status,
    SmsDispatchMode? smsDispatchMode,
    List<FallbackSmsTarget>? fallbackTargets,
    double? latitude,
    double? longitude,
  }) => Incident(
    id: id,
    kind: kind,
    status: status ?? this.status,
    createdAt: createdAt,
    confidence: confidence,
    smsDispatchMode: smsDispatchMode ?? this.smsDispatchMode,
    fallbackTargets: fallbackTargets ?? this.fallbackTargets,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
  );
}
