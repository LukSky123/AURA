import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../domain.dart';

class ThreatPrediction {
  const ThreatPrediction({
    required this.kind,
    required this.className,
    required this.confidence,
    required this.probabilities,
    required this.thresholdUsed,
    required this.timestamp,
  });

  final IncidentKind kind;
  final String className;
  final double confidence;
  final Map<String, double> probabilities;
  final double thresholdUsed;
  final DateTime timestamp;

  @override
  String toString() =>
      'ThreatPrediction($className, ${(confidence * 100).toStringAsFixed(1)}% [Threshold: ${(thresholdUsed * 100).toStringAsFixed(0)}%])';
}

/// ThreatDetectorService manages the AURA 4-class acoustic classifier.
///
/// Features:
/// - Loads 'aura_model.tflite' via tflite_flutter.
/// - Explicitly calls resizeInputTensor(0, [15600]) and allocateTensors()
///   to satisfy the dynamic [-1] input shape signature for 0.975s 16 kHz audio.
/// - Evaluates classes: ['gunshot', 'glass_break', 'explosion', 'neutral_ambient'].
/// - Suppresses 'neutral_ambient' and requires 80% baseline confidence.
/// - Dynamic threshold backoff: if a false alarm is reported, raises threshold
///   to 95% for 15 minutes.
class ThreatDetectorService {
  static const int inputSampleLength = 15600; // 0.975s at 16 kHz
  static const List<String> classes = [
    'gunshot',
    'glass_break',
    'explosion',
    'neutral_ambient',
  ];

  static const double baselineThreshold = 0.80; // 80%
  static const double backoffThreshold = 0.95;  // 95%
  static const Duration backoffDuration = Duration(minutes: 15);

  Interpreter? _interpreter;
  DateTime? _backoffUntil;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Returns true if dynamic threshold backoff (95%) is currently active.
  bool get isBackoffActive {
    final until = _backoffUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// Current active confidence threshold required for threats.
  double get currentThreshold => isBackoffActive ? backoffThreshold : baselineThreshold;

  /// Time remaining on threshold backoff, or null if inactive.
  Duration? get backoffRemaining {
    final until = _backoffUntil;
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Initializes the TFLite interpreter and allocates memory for 15,600 samples.
  Future<void> initialize({String modelPath = 'assets/models/aura_model.tflite'}) async {
    if (_isInitialized && _interpreter != null) return;

    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(modelPath, options: options);

      // CRITICAL: YAMNet dynamic input [-1] must be explicitly resized to [15600]
      _interpreter!.resizeInputTensor(0, [inputSampleLength]);
      _interpreter!.allocateTensors();

      _isInitialized = true;
      debugPrint('[ThreatDetector] Loaded $modelPath successfully with input shape [15600]');
    } catch (e, stack) {
      debugPrint('[ThreatDetector] Initialization failed: $e\n$stack');
      rethrow;
    }
  }

  /// Triggers dynamic threshold backoff: elevates threat threshold to 95% for 15 minutes.
  void recordFalseAlarm() {
    _backoffUntil = DateTime.now().add(backoffDuration);
    debugPrint('[ThreatDetector] False alarm logged. Dynamic threshold elevated to 95% until $_backoffUntil');
  }

  /// Manually clears any active threshold backoff.
  void clearBackoff() {
    _backoffUntil = null;
    debugPrint('[ThreatDetector] Threshold backoff cleared. Restored to 80% baseline.');
  }

  /// Runs inference on a 15,600-sample Float32 normalized audio window.
  ///
  /// Returns a ThreatPrediction if a threat class meets or exceeds the active threshold,
  /// or null if neutral_ambient dominates or confidence is below threshold.
  Future<ThreatPrediction?> predict(Float32List audioBuffer) async {
    final interpreter = _interpreter;
    if (!_isInitialized || interpreter == null) {
      throw StateError('ThreatDetectorService must be initialized before calling predict()');
    }

    if (audioBuffer.length != inputSampleLength) {
      throw ArgumentError('Input buffer must have length $inputSampleLength, got ${audioBuffer.length}');
    }

    // Yield to the event loop so background processing does not stall UI frame rendering
    await Future<void>.delayed(Duration.zero);

    // Prepare output container [1, 4]
    final output = List<List<double>>.generate(
      1,
      (_) => List<double>.filled(classes.length, 0.0),
    );

    // Run inference through YAMNet + Custom Head
    interpreter.run(audioBuffer, output);

    final rawProbabilities = output[0];
    final probMap = <String, double>{};
    for (int i = 0; i < classes.length; i++) {
      probMap[classes[i]] = rawProbabilities[i];
    }

    // Find top class
    int bestIdx = 0;
    double maxProb = rawProbabilities[0];
    for (int i = 1; i < rawProbabilities.length; i++) {
      if (rawProbabilities[i] > maxProb) {
        maxProb = rawProbabilities[i];
        bestIdx = i;
      }
    }

    final topClass = classes[bestIdx];
    final activeThreshold = currentThreshold;

    // 1. Suppress neutral_ambient
    if (topClass == 'neutral_ambient') {
      return null;
    }

    // 2. Check active threat threshold (80% baseline or 95% during backoff)
    if (maxProb >= activeThreshold) {
      final kind = _mapToIncidentKind(topClass);
      if (kind != null) {
        return ThreatPrediction(
          kind: kind,
          className: topClass,
          confidence: maxProb,
          probabilities: probMap,
          thresholdUsed: activeThreshold,
          timestamp: DateTime.now(),
        );
      }
    }

    return null;
  }

  IncidentKind? _mapToIncidentKind(String name) {
    switch (name) {
      case 'gunshot':
        return IncidentKind.gunshot;
      case 'glass_break':
        return IncidentKind.glassBreak;
      case 'explosion':
        return IncidentKind.explosion;
      default:
        return null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
