import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_mobile/domain.dart';
import 'package:aura_mobile/services/entitlement_service.dart';
import 'package:aura_mobile/services/threat_detector_service.dart';
import 'package:aura_mobile/services/audio_stream_controller.dart';

void main() {
  group('EntitlementService & Monetization Tier Tests', () {
    test('Free tier defaults to 2 contacts and 2 cloud SMS credits', () {
      final service = DefaultEntitlementService();
      expect(service.current.tier, SubscriptionTier.free);
      expect(service.current.contactLimit, 2);
      expect(service.current.canSendCloudSms, isTrue);
      expect(service.current.remainingCloudSmsCredits, 2);
      expect(service.current.canUseSmartRouting, isFalse);
      expect(service.current.hasCircleSiren, isFalse);

      expect(service.canAddContact(0), isTrue);
      expect(service.canAddContact(1), isTrue);
      expect(service.canAddContact(2), isFalse);
    });

    test('Upgrading to Pro tier enables 5 contacts, unlimited SMS, and transit watch', () async {
      final service = DefaultEntitlementService();
      final success = await service.purchaseSubscription(SubscriptionTier.pro);
      expect(success, isTrue);
      expect(service.current.tier, SubscriptionTier.pro);
      expect(service.current.contactLimit, 5);
      expect(service.current.canSendCloudSms, isTrue);
      expect(service.current.canUseSmartRouting, isTrue);
      expect(service.current.hasTransitWatch, isTrue);
      expect(service.current.hasCircleSiren, isFalse);

      expect(service.canAddContact(4), isTrue);
      expect(service.canAddContact(5), isFalse);
    });

    test('Upgrading to Family tier enables circle sirens', () async {
      final service = DefaultEntitlementService();
      await service.purchaseSubscription(SubscriptionTier.family);
      expect(service.current.tier, SubscriptionTier.family);
      expect(service.current.hasCircleSiren, isTrue);
      expect(service.current.hasTransitWatch, isTrue);
      expect(service.current.canUseSmartRouting, isTrue);
    });
  });

  group('ThreatDetectorService Dynamic Backoff Tests', () {
    test('Default threshold is 80% baseline', () {
      final detector = ThreatDetectorService();
      expect(detector.isBackoffActive, isFalse);
      expect(detector.currentThreshold, 0.80);
      expect(detector.backoffRemaining, isNull);
    });

    test('False alarm triggers 95% sensitivity backoff', () {
      final detector = ThreatDetectorService();
      detector.recordFalseAlarm();

      expect(detector.isBackoffActive, isTrue);
      expect(detector.currentThreshold, 0.95);
      expect(detector.backoffRemaining, isNotNull);
      expect(detector.backoffRemaining!.inMinutes, greaterThanOrEqualTo(14));

      detector.resetBackoff();
      expect(detector.isBackoffActive, isFalse);
      expect(detector.currentThreshold, 0.80);
    });
  });

  group('CircularAudioBuffer Sliding Window Tests', () {
    test('Ingests chunks and extracts full snapshot', () {
      const capacity = 100;
      final buffer = CircularAudioBuffer(capacity);
      expect(buffer.isFull, isFalse);
      expect(buffer.count, 0);

      // Write 60 samples
      final chunk1 = Float32List.fromList(List.generate(60, (i) => i.toDouble()));
      buffer.writeSamples(chunk1);
      expect(buffer.count, 60);
      expect(buffer.isFull, isFalse);

      // Write 60 more samples (causing wraparound of 20 samples)
      final chunk2 = Float32List.fromList(List.generate(60, (i) => (60 + i).toDouble()));
      buffer.writeSamples(chunk2);
      expect(buffer.count, 100);
      expect(buffer.isFull, isTrue);

      final snapshot = buffer.snapshot();
      expect(snapshot.length, capacity);
      // The oldest 20 samples [0..19] were overwritten; snapshot should start at sample 20
      expect(snapshot.first, 20.0);
      expect(snapshot.last, 119.0);
    });
  });

  group('Incident Domain Model Tests', () {
    test('Incident copyWith preserves and updates GPS coordinates and SMS dispatch mode', () {
      final now = DateTime.now().toUtc();
      final incident = Incident(
        id: 'inc-123',
        kind: IncidentKind.gunshot,
        status: IncidentStatus.countdown,
        createdAt: now,
      );

      expect(incident.latitude, isNull);
      expect(incident.longitude, isNull);

      final dispatched = incident.copyWith(
        status: IncidentStatus.dispatched,
        smsDispatchMode: SmsDispatchMode.fallbackToLocalSim,
        latitude: 6.5244,
        longitude: 3.3792,
        fallbackTargets: const [
          FallbackSmsTarget(phone: '+2348011112222', message: 'Alert!'),
        ],
      );

      expect(dispatched.id, 'inc-123');
      expect(dispatched.status, IncidentStatus.dispatched);
      expect(dispatched.smsDispatchMode, SmsDispatchMode.fallbackToLocalSim);
      expect(dispatched.latitude, 6.5244);
      expect(dispatched.longitude, 3.3792);
      expect(dispatched.fallbackTargets.length, 1);
    });
  });
}
