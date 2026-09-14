import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain.dart';

class IncidentDispatchResult {
  const IncidentDispatchResult({
    required this.incident,
    required this.mode,
    this.fallbackTargets = const [],
    this.notifiedContactsCount = 0,
    this.isQueuedOffline = false,
  });

  final Incident incident;
  final SmsDispatchMode mode;
  final List<FallbackSmsTarget> fallbackTargets;
  final int notifiedContactsCount;
  final bool isQueuedOffline;
}

class IncidentSyncUpdate {
  const IncidentSyncUpdate({
    required this.incidentId,
    required this.status,
    this.acknowledgedCount = 0,
    this.confirmedCount = 0,
    this.latestLatitude,
    this.latestLongitude,
    required this.updatedAt,
  });

  final String incidentId;
  final IncidentStatus status;
  final int acknowledgedCount;
  final int confirmedCount;
  final double? latestLatitude;
  final double? latestLongitude;
  final DateTime updatedAt;
}

class QueuedLocationPoint {
  const QueuedLocationPoint({
    required this.incidentId,
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    required this.recordedAt,
  });

  final String incidentId;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
        'incidentId': incidentId,
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyM != null) 'accuracyM': accuracyM,
        'recordedAt': recordedAt.toIso8601String(),
      };
}

class OfflineIncidentQueue {
  final List<Incident> pendingIncidents = [];
  final List<QueuedLocationPoint> pendingLocationPoints = [];
  final List<String> pendingCancellations = [];
  final List<String> pendingResolutions = [];

  bool get isEmpty =>
      pendingIncidents.isEmpty &&
      pendingLocationPoints.isEmpty &&
      pendingCancellations.isEmpty &&
      pendingResolutions.isEmpty;

  int get count =>
      pendingIncidents.length +
      pendingLocationPoints.length +
      pendingCancellations.length +
      pendingResolutions.length;

  void enqueueIncident(Incident incident) => pendingIncidents.add(incident);
  void enqueueLocation(QueuedLocationPoint pt) => pendingLocationPoints.add(pt);
  void enqueueCancellation(String id) => pendingCancellations.add(id);
  void enqueueResolution(String id) => pendingResolutions.add(id);

  void clear() {
    pendingIncidents.clear();
    pendingLocationPoints.clear();
    pendingCancellations.clear();
    pendingResolutions.clear();
  }
}

abstract class IncidentRepository {
  Future<IncidentDispatchResult> dispatch(Incident incident);
  Future<void> cancel(String incidentId, {String reason = 'false_alarm'});
  Future<void> resolve(String incidentId);
  Future<void> ingestLocation({
    required String incidentId,
    required double latitude,
    required double longitude,
    double? accuracyM,
    DateTime? recordedAt,
  });
  Stream<IncidentSyncUpdate> subscribeToIncident(String incidentId);
  Future<int> flushOfflineQueue();
  int get offlineQueueCount;
}

/// Production IncidentRepository leveraging Supabase Edge Functions, Realtime, and local offline queuing.
class SupabaseIncidentRepository implements IncidentRepository {
  SupabaseIncidentRepository({
    SupabaseClient? client,
    OfflineIncidentQueue? queue,
  })  : _client = client,
        _queue = queue ?? OfflineIncidentQueue();

  final SupabaseClient? _client;
  final OfflineIncidentQueue _queue;

  SupabaseClient? get _activeClient {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  int get offlineQueueCount => _queue.count;

  @override
  Future<IncidentDispatchResult> dispatch(Incident incident) async {
    final client = _activeClient;

    if (client == null) {
      if (kDebugMode) {
        debugPrint('[IncidentRepo] Supabase client unavailable. Enqueuing incident offline.');
      }
      _queue.enqueueIncident(incident);
      return IncidentDispatchResult(
        incident: incident.copyWith(status: IncidentStatus.dispatched),
        mode: SmsDispatchMode.fallbackToLocalSim,
        fallbackTargets: incident.fallbackTargets,
        isQueuedOffline: true,
      );
    }

    try {
      final response = await client.functions.invoke(
        'create-incident',
        body: {
          'id': incident.id,
          'kind': incident.kind.name,
          'confidence': incident.confidence,
          'latitude': incident.latitude,
          'longitude': incident.longitude,
          'modelVersion': 'yamnet-aura-v1',
          'channel': 'mobile_app',
        },
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data is Map ? response.data as Map : {};
        final modeStr = data['sms_dispatch_mode'] as String?;
        final isCloud = modeStr == 'cloud_termii';
        final count = (data['notified_contacts_count'] as num?)?.toInt() ?? 0;

        List<FallbackSmsTarget> targets = [];
        if (!isCloud && data['fallback_targets'] is List) {
          final list = data['fallback_targets'] as List;
          targets = list.map((item) {
            final m = item as Map;
            return FallbackSmsTarget(
              phone: m['phone'] as String? ?? '',
              message: m['message'] as String? ?? '',
            );
          }).toList();
        }

        return IncidentDispatchResult(
          incident: incident.copyWith(
            status: IncidentStatus.dispatched,
            smsDispatchMode: isCloud ? SmsDispatchMode.cloudTermii : SmsDispatchMode.fallbackToLocalSim,
            fallbackTargets: targets.isNotEmpty ? targets : incident.fallbackTargets,
          ),
          mode: isCloud ? SmsDispatchMode.cloudTermii : SmsDispatchMode.fallbackToLocalSim,
          fallbackTargets: targets.isNotEmpty ? targets : incident.fallbackTargets,
          notifiedContactsCount: count,
          isQueuedOffline: false,
        );
      } else {
        throw StateError('Edge function returned status ${response.status}: ${response.data}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IncidentRepo] Network dispatch failed ($e). Storing in offline queue.');
      }
      _queue.enqueueIncident(incident);
      return IncidentDispatchResult(
        incident: incident.copyWith(status: IncidentStatus.dispatched),
        mode: SmsDispatchMode.fallbackToLocalSim,
        fallbackTargets: incident.fallbackTargets,
        isQueuedOffline: true,
      );
    }
  }

  @override
  Future<void> cancel(String incidentId, {String reason = 'false_alarm'}) async {
    final client = _activeClient;
    if (client == null) {
      _queue.enqueueCancellation(incidentId);
      return;
    }

    try {
      await client.functions.invoke(
        'cancel-incident',
        body: {
          'incidentId': incidentId,
          'reason': reason,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IncidentRepo] Failed to cancel incident online ($e). Queuing cancellation.');
      }
      _queue.enqueueCancellation(incidentId);
    }
  }

  @override
  Future<void> resolve(String incidentId) async {
    final client = _activeClient;
    if (client == null) {
      _queue.enqueueResolution(incidentId);
      return;
    }

    try {
      await client.functions.invoke(
        'resolve-incident',
        body: {'incidentId': incidentId},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IncidentRepo] Failed to resolve incident online ($e). Queuing resolution.');
      }
      _queue.enqueueResolution(incidentId);
    }
  }

  @override
  Future<void> ingestLocation({
    required String incidentId,
    required double latitude,
    required double longitude,
    double? accuracyM,
    DateTime? recordedAt,
  }) async {
    final client = _activeClient;
    final now = recordedAt ?? DateTime.now().toUtc();

    if (client == null) {
      _queue.enqueueLocation(QueuedLocationPoint(
        incidentId: incidentId,
        latitude: latitude,
        longitude: longitude,
        accuracyM: accuracyM,
        recordedAt: now,
      ));
      return;
    }

    try {
      await client.functions.invoke(
        'ingest-location',
        body: {
          'incidentId': incidentId,
          'latitude': latitude,
          'longitude': longitude,
          'accuracyM': accuracyM,
          'recordedAt': now.toIso8601String(),
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IncidentRepo] Location ingest failed ($e). Queuing GPS point.');
      }
      _queue.enqueueLocation(QueuedLocationPoint(
        incidentId: incidentId,
        latitude: latitude,
        longitude: longitude,
        accuracyM: accuracyM,
        recordedAt: now,
      ));
    }
  }

  @override
  Stream<IncidentSyncUpdate> subscribeToIncident(String incidentId) {
    final client = _activeClient;
    if (client == null) {
      return const Stream.empty();
    }

    final controller = StreamController<IncidentSyncUpdate>.broadcast();

    // Query initial status via RPC
    client.rpc('get_incident_live_status', params: {'p_incident_id': incidentId}).then((result) {
      if (result is Map && !controller.isClosed) {
        final inc = result['incident'] as Map?;
        final loc = result['latest_location'] as Map?;
        final ack = (result['acknowledged_count'] as num?)?.toInt() ?? 0;
        final conf = (result['confirmed_count'] as num?)?.toInt() ?? 0;

        if (inc != null) {
          final statusStr = inc['status'] as String? ?? 'dispatched';
          controller.add(IncidentSyncUpdate(
            incidentId: incidentId,
            status: _parseStatus(statusStr),
            acknowledgedCount: ack,
            confirmedCount: conf,
            latestLatitude: (loc?['latitude'] as num?)?.toDouble(),
            latestLongitude: (loc?['longitude'] as num?)?.toDouble(),
            updatedAt: DateTime.now().toUtc(),
          ));
        }
      }
    }).catchError((_) {});

    // Listen to real-time changes
    final channel = client.channel('public:incidents:id=eq.$incidentId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'incidents',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: incidentId,
      ),
      callback: (payload) {
        if (controller.isClosed) return;
        final record = payload.newRecord;
        final statusStr = record['status'] as String? ?? 'dispatched';
        controller.add(IncidentSyncUpdate(
          incidentId: incidentId,
          status: _parseStatus(statusStr),
          updatedAt: DateTime.now().toUtc(),
        ));
      },
    ).subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
    };

    return controller.stream;
  }

  @override
  Future<int> flushOfflineQueue() async {
    final client = _activeClient;
    if (client == null || _queue.isEmpty) return 0;

    int flushedCount = 0;

    // 1. Flush pending incidents
    final incidentsCopy = List<Incident>.from(_queue.pendingIncidents);
    for (final inc in incidentsCopy) {
      try {
        final res = await client.functions.invoke(
          'create-incident',
          body: {
            'id': inc.id,
            'kind': inc.kind.name,
            'confidence': inc.confidence,
            'latitude': inc.latitude,
            'longitude': inc.longitude,
            'modelVersion': 'yamnet-aura-v1',
            'channel': 'offline_sync',
          },
        );
        if (res.status >= 200 && res.status < 300) {
          _queue.pendingIncidents.remove(inc);
          flushedCount++;
        }
      } catch (_) {
        break; // Network still unavailable
      }
    }

    // 2. Flush pending location points in batch
    if (_queue.pendingLocationPoints.isNotEmpty) {
      final pointsByIncident = <String, List<QueuedLocationPoint>>{};
      for (final pt in _queue.pendingLocationPoints) {
        pointsByIncident.putIfAbsent(pt.incidentId, () => []).add(pt);
      }

      for (final entry in pointsByIncident.entries) {
        try {
          final res = await client.functions.invoke(
            'ingest-location',
            body: {
              'incidentId': entry.key,
              'points': entry.value.map((p) => {
                'latitude': p.latitude,
                'longitude': p.longitude,
                if (p.accuracyM != null) 'accuracyM': p.accuracyM,
                'recordedAt': p.recordedAt.toIso8601String(),
              }).toList(),
            },
          );
          if (res.status >= 200 && res.status < 300) {
            _queue.pendingLocationPoints.removeWhere((p) => p.incidentId == entry.key);
            flushedCount += entry.value.length;
          }
        } catch (_) {
          break;
        }
      }
    }

    // 3. Flush pending cancellations
    final cancellationsCopy = List<String>.from(_queue.pendingCancellations);
    for (final id in cancellationsCopy) {
      try {
        final res = await client.functions.invoke(
          'cancel-incident',
          body: {'incidentId': id, 'reason': 'offline_sync'},
        );
        if (res.status >= 200 && res.status < 300) {
          _queue.pendingCancellations.remove(id);
          flushedCount++;
        }
      } catch (_) {
        break;
      }
    }

    return flushedCount;
  }

  static IncidentStatus _parseStatus(String status) => switch (status) {
        'countdown' => IncidentStatus.countdown,
        'dispatched' => IncidentStatus.dispatched,
        'acknowledged' => IncidentStatus.acknowledged,
        'resolved' => IncidentStatus.resolved,
        'cancelled' => IncidentStatus.cancelled,
        _ => IncidentStatus.dispatched,
      };
}

/// Fallback in-memory mock repository used during unit testing and offline development.
class DeferredIncidentRepository implements IncidentRepository {
  DeferredIncidentRepository({OfflineIncidentQueue? queue})
      : _queue = queue ?? OfflineIncidentQueue();

  final OfflineIncidentQueue _queue;

  @override
  int get offlineQueueCount => _queue.count;

  @override
  Future<void> cancel(String incidentId, {String reason = 'false_alarm'}) async {
    _queue.enqueueCancellation(incidentId);
  }

  @override
  Future<IncidentDispatchResult> dispatch(Incident incident) async {
    return IncidentDispatchResult(
      incident: incident.copyWith(status: IncidentStatus.dispatched),
      mode: incident.smsDispatchMode ?? SmsDispatchMode.cloudTermii,
      fallbackTargets: incident.fallbackTargets,
      notifiedContactsCount: 2,
    );
  }

  @override
  Future<void> ingestLocation({
    required String incidentId,
    required double latitude,
    required double longitude,
    double? accuracyM,
    DateTime? recordedAt,
  }) async {
    _queue.enqueueLocation(QueuedLocationPoint(
      incidentId: incidentId,
      latitude: latitude,
      longitude: longitude,
      accuracyM: accuracyM,
      recordedAt: recordedAt ?? DateTime.now().toUtc(),
    ));
  }

  @override
  Future<void> resolve(String incidentId) async {
    _queue.enqueueResolution(incidentId);
  }

  @override
  Stream<IncidentSyncUpdate> subscribeToIncident(String incidentId) =>
      const Stream.empty();

  @override
  Future<int> flushOfflineQueue() async {
    final count = _queue.count;
    _queue.clear();
    return count;
  }
}
