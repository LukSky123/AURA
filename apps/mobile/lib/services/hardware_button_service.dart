import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service interfacing with native Android hardware button events (via AccessibilityService)
/// and system power/battery optimization settings.
class HardwareButtonService {
  static const MethodChannel _nativeMethods =
      MethodChannel('com.aura.safety/native_controls');
  static const EventChannel _hardwareEventsChannel =
      EventChannel('com.aura.safety/hardware_events');

  final StreamController<String> _hardwareEventsController =
      StreamController<String>.broadcast();
  StreamSubscription<dynamic>? _subscription;

  HardwareButtonService() {
    _initEventChannel();
  }

  /// Broadcast stream of hardware shortcut events:
  /// - 'instant_dispatch' (Volume Up double-press within 650ms)
  /// - 'cancel_countdown' (Volume Down double-press within 650ms)
  Stream<String> get hardwareEvents => _hardwareEventsController.stream;

  void _initEventChannel() {
    try {
      _subscription = _hardwareEventsChannel
          .receiveBroadcastStream()
          .listen(
            (dynamic event) {
              if (event is String) {
                if (kDebugMode) {
                  debugPrint('[HardwareButtonService] Hardware event received: $event');
                }
                _hardwareEventsController.add(event);
              }
            },
            onError: (Object error) {
              if (kDebugMode) {
                debugPrint('[HardwareButtonService] Event stream error: $error');
              }
            },
          );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HardwareButtonService] Failed to listen to hardware events: $e');
      }
    }
  }

  /// Checks if AuraAccessibilityService is active in Android Accessibility settings.
  Future<bool> isAccessibilityEnabled() async {
    try {
      final bool? isEnabled =
          await _nativeMethods.invokeMethod<bool>('isAccessibilityEnabled');
      return isEnabled ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HardwareButtonService] isAccessibilityEnabled error: $e');
      }
      return false;
    }
  }

  /// Directs user to Android Accessibility settings to enable AURA shortcuts.
  Future<void> openAccessibilitySettings() async {
    try {
      await _nativeMethods.invokeMethod<void>('openAccessibilitySettings');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HardwareButtonService] openAccessibilitySettings error: $e');
      }
    }
  }

  /// Checks if battery optimization has been disabled for AURA (anti-OEM kill).
  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final bool? isIgnored =
          await _nativeMethods.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return isIgnored ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HardwareButtonService] isBatteryOptimizationIgnored error: $e');
      }
      return false;
    }
  }

  /// Prompts system dialog requesting user exemption from battery optimization.
  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _nativeMethods.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HardwareButtonService] requestIgnoreBatteryOptimizations error: $e');
      }
    }
  }

  /// Starts the sticky audio detection foreground service with wake lock.
  Future<void> startForegroundService() async {
    try {
      await _nativeMethods.invokeMethod<void>('startForegroundService');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HardwareButtonService] startForegroundService error: $e');
      }
    }
  }

  /// Stops the audio detection foreground service.
  Future<void> stopForegroundService() async {
    try {
      await _nativeMethods.invokeMethod<void>('stopForegroundService');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[HardwareButtonService] stopForegroundService error: $e');
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _hardwareEventsController.close();
  }
}
