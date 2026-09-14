import 'dart:async';
import '../domain.dart';
import 'audio_stream_controller.dart';
import 'threat_detector_service.dart';

class DetectionEvent {
  const DetectionEvent(this.kind, this.confidence, {this.probabilities});
  final IncidentKind kind;
  final double confidence;
  final Map<String, double>? probabilities;
}

/// Abstract contract for acoustic threat detection.
abstract class DetectionService {
  Stream<DetectionEvent> get events;
  Future<void> start();
  Future<void> stop();
  void recordFalseAlarm();
}

/// Concrete production implementation utilizing AudioStreamController and ThreatDetectorService.
class StreamingDetectionService implements DetectionService {
  StreamingDetectionService({AudioStreamController? controller})
      : _controller = controller ?? AudioStreamController();

  final AudioStreamController _controller;

  AudioStreamController get controller => _controller;
  ThreatDetectorService get detector => _controller.detector;

  @override
  Stream<DetectionEvent> get events => _controller.threatStream.map(
        (t) => DetectionEvent(
          t.kind,
          t.confidence,
          probabilities: t.probabilities,
        ),
      );

  @override
  Future<void> start() => _controller.start();

  @override
  Future<void> stop() => _controller.stop();

  @override
  void recordFalseAlarm() => _controller.recordFalseAlarm();

  void dispose() => _controller.dispose();
}
