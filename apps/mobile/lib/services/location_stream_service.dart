import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Manages GPS location querying and continuous tracking during active incidents.
class LocationStreamService {
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<Position> _locationStreamController =
      StreamController<Position>.broadcast();

  Stream<Position> get locationStream => _locationStreamController.stream;
  Position? _lastKnownPosition;
  Position? get lastKnownPosition => _lastKnownPosition;

  /// Ensures GPS location service and permissions are active.
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) {
        debugPrint('[LocationService] Location services are disabled.');
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          debugPrint('[LocationService] Location permission denied.');
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        debugPrint('[LocationService] Location permissions are permanently denied.');
      }
      return false;
    }

    return true;
  }

  /// Fetches one-shot current GPS position with high accuracy.
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _lastKnownPosition = position;
      return position;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LocationService] Error obtaining current position: $e');
      }
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) _lastKnownPosition = last;
        return last;
      } catch (_) {
        return null;
      }
    }
  }

  /// Begins continuous GPS tracking stream for active countdown or dispatched incident.
  Future<void> startTracking({
    required String incidentId,
    Future<void> Function(Position pos)? onPositionUpdate,
  }) async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return;

    await stopTracking();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) async {
        _lastKnownPosition = position;
        _locationStreamController.add(position);
        if (kDebugMode) {
          debugPrint(
            '[LocationService] Incident $incidentId update: ${position.latitude}, ${position.longitude} (acc: ${position.accuracy}m)',
          );
        }
        if (onPositionUpdate != null) {
          try {
            await onPositionUpdate(position);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[LocationService] onPositionUpdate callback error: $e');
            }
          }
        }
      },
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('[LocationService] Position stream error: $error');
        }
      },
    );
  }

  /// Halts GPS tracking stream.
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() {
    stopTracking();
    _locationStreamController.close();
  }
}
