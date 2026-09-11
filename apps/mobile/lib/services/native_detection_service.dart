import 'dart:async';

import 'package:flutter/services.dart';

import '../domain.dart';
import 'detection_service.dart';

class NativeDetectionService implements DetectionService {
  static const _methods = MethodChannel('com.aura.safety/detection');
  static const _events = EventChannel('com.aura.safety/detection-events');
  final StreamController<DetectionEvent> _controller =
      StreamController.broadcast();
  StreamSubscription<dynamic>? _subscription;

  @override
  Stream<DetectionEvent> get events => _controller.stream;

  @override
  Future<void> start() async {
    _subscription ??= _events.receiveBroadcastStream().listen((payload) {
      if (payload is! Map) return;
      final kind = switch (payload['kind']) {
        'gunshot' => IncidentKind.gunshot,
        'glass_break' => IncidentKind.glassBreak,
        'collision' => IncidentKind.collision,
        'explosion' => IncidentKind.explosion,
        _ => null,
      };
      final confidence = (payload['confidence'] as num?)?.toDouble();
      if (kind != null && confidence != null)
        _controller.add(DetectionEvent(kind, confidence));
    });
    await _methods.invokeMethod<void>('start');
  }

  @override
  Future<void> stop() async {
    await _methods.invokeMethod<void>('stop');
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
