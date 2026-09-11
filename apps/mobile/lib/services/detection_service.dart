import '../domain.dart';

class DetectionEvent {
  const DetectionEvent(this.kind, this.confidence);
  final IncidentKind kind;
  final double confidence;
}

/// Native Android/iOS implementations feed this contract. The product layer
/// intentionally owns escalation policy so the same 0.85 threshold is audited
/// across platforms, even though their lifecycle capabilities differ.
abstract class DetectionService {
  Stream<DetectionEvent> get events;
  Future<void> start();
  Future<void> stop();
}
