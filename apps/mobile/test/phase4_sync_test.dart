import 'package:flutter_test/flutter_test.dart';
import 'package:aura_mobile/domain.dart';
import 'package:aura_mobile/services/incident_repository.dart';

void main() {
  group('OfflineIncidentQueue Tests', () {
    test('Enqueueing incidents, location points, and cancellations updates counts', () {
      final queue = OfflineIncidentQueue();
      expect(queue.isEmpty, isTrue);
      expect(queue.count, 0);

      final incident = Incident(
        id: 'inc-001',
        kind: IncidentKind.gunshot,
        status: IncidentStatus.countdown,
        createdAt: DateTime.utc(2026, 9, 14, 12, 0, 0),
      );

      queue.enqueueIncident(incident);
      expect(queue.isEmpty, isFalse);
      expect(queue.count, 1);
      expect(queue.pendingIncidents.length, 1);

      queue.enqueueLocation(QueuedLocationPoint(
        incidentId: 'inc-001',
        latitude: 6.5244,
        longitude: 3.3792,
        accuracyM: 5.0,
        recordedAt: DateTime.now().toUtc(),
      ));
      expect(queue.count, 2);
      expect(queue.pendingLocationPoints.length, 1);

      queue.enqueueCancellation('inc-001');
      expect(queue.count, 3);
      expect(queue.pendingCancellations.length, 1);

      queue.clear();
      expect(queue.isEmpty, isTrue);
      expect(queue.count, 0);
    });

    test('QueuedLocationPoint serializes correctly to JSON', () {
      final now = DateTime.utc(2026, 9, 14, 12, 0, 0);
      final point = QueuedLocationPoint(
        incidentId: 'inc-999',
        latitude: 9.0765,
        longitude: 7.3986,
        accuracyM: 4.2,
        recordedAt: now,
      );

      final json = point.toJson();
      expect(json['incidentId'], 'inc-999');
      expect(json['latitude'], 9.0765);
      expect(json['longitude'], 7.3986);
      expect(json['accuracyM'], 4.2);
      expect(json['recordedAt'], '2026-09-14T12:00:00.000Z');
    });
  });

  group('SupabaseIncidentRepository Offline Fallback Tests', () {
    test('Dispatches gracefully into offline queue when client is uninitialized', () async {
      final queue = OfflineIncidentQueue();
      final repository = SupabaseIncidentRepository(queue: queue);

      final now = DateTime.now().toUtc();
      final incident = Incident(
        id: 'offline-inc-1',
        kind: IncidentKind.manualSos,
        status: IncidentStatus.countdown,
        createdAt: now,
        fallbackTargets: const [
          FallbackSmsTarget(phone: '+2348011112222', message: 'SOS!'),
        ],
      );

      final result = await repository.dispatch(incident);

      expect(result.isQueuedOffline, isTrue);
      expect(result.mode, SmsDispatchMode.fallbackToLocalSim);
      expect(result.fallbackTargets.length, 1);
      expect(repository.offlineQueueCount, 1);
      expect(queue.pendingIncidents.first.id, 'offline-inc-1');
    });

    test('Buffers GPS locations into offline queue when client is uninitialized', () async {
      final queue = OfflineIncidentQueue();
      final repository = SupabaseIncidentRepository(queue: queue);

      await repository.ingestLocation(
        incidentId: 'offline-inc-1',
        latitude: 6.6018,
        longitude: 3.3515,
        accuracyM: 3.0,
      );

      expect(repository.offlineQueueCount, 1);
      expect(queue.pendingLocationPoints.first.incidentId, 'offline-inc-1');
      expect(queue.pendingLocationPoints.first.latitude, 6.6018);
      expect(queue.pendingLocationPoints.first.longitude, 3.3515);
    });

    test('Buffers cancellations into offline queue when client is uninitialized', () async {
      final queue = OfflineIncidentQueue();
      final repository = SupabaseIncidentRepository(queue: queue);

      await repository.cancel('offline-inc-1', reason: 'false_alarm');

      expect(repository.offlineQueueCount, 1);
      expect(queue.pendingCancellations.first, 'offline-inc-1');
    });
  });

  group('IncidentSyncUpdate Structure Tests', () {
    test('Maintains acknowledgement metrics and real-time coordinates', () {
      final now = DateTime.now().toUtc();
      final update = IncidentSyncUpdate(
        incidentId: 'live-sync-1',
        status: IncidentStatus.acknowledged,
        acknowledgedCount: 2,
        confirmedCount: 1,
        latestLatitude: 6.4531,
        latestLongitude: 3.4211,
        updatedAt: now,
      );

      expect(update.incidentId, 'live-sync-1');
      expect(update.status, IncidentStatus.acknowledged);
      expect(update.acknowledgedCount, 2);
      expect(update.confirmedCount, 1);
      expect(update.latestLatitude, 6.4531);
      expect(update.latestLongitude, 3.4211);
      expect(update.updatedAt, now);
    });
  });
}
