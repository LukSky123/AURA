import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'threat_detector_service.dart';

/// High-performance circular buffer for holding 15,600 normalized Float32 samples.
class CircularAudioBuffer {
  CircularAudioBuffer(this.capacity) : _buffer = Float32List(capacity);

  final int capacity;
  final Float32List _buffer;
  int _writeIndex = 0;
  int _totalWritten = 0;

  bool get isFull => _totalWritten >= capacity;
  int get count => _totalWritten < capacity ? _totalWritten : capacity;

  void writeSamples(Float32List samples) {
    for (int i = 0; i < samples.length; i++) {
      _buffer[_writeIndex] = samples[i];
      _writeIndex = (_writeIndex + 1) % capacity;
      if (_totalWritten < capacity) _totalWritten++;
    }
  }

  /// Returns a snapshot of the last [capacity] samples in chronological order.
  Float32List snapshot() {
    final result = Float32List(capacity);
    if (!isFull) {
      result.setRange(0, _writeIndex, _buffer);
      return result;
    }

    final firstPartLength = capacity - _writeIndex;
    result.setRange(0, firstPartLength, _buffer, _writeIndex);
    result.setRange(firstPartLength, capacity, _buffer, 0);
    return result;
  }

  void clear() {
    _buffer.fillRange(0, capacity, 0.0);
    _writeIndex = 0;
    _totalWritten = 0;
  }
}

/// AudioStreamController coordinates raw microphone capture, sliding buffer management,
/// and scheduled periodic TFLite inference every 500 ms.
class AudioStreamController {
  AudioStreamController({ThreatDetectorService? detector})
      : _detector = detector ?? ThreatDetectorService();

  final ThreatDetectorService _detector;
  final AudioRecorder _recorder = AudioRecorder();
  final CircularAudioBuffer _buffer = CircularAudioBuffer(ThreatDetectorService.inputSampleLength);

  final StreamController<ThreatPrediction> _threatController = StreamController<ThreatPrediction>.broadcast();
  final StreamController<bool> _listeningController = StreamController<bool>.broadcast();

  StreamSubscription<Uint8List>? _pcmSubscription;
  Timer? _inferenceTimer;
  bool _isListening = false;
  bool _isProcessingInference = false;

  /// Stream emitting qualified acoustic threats (confidence >= active threshold).
  Stream<ThreatPrediction> get threatStream => _threatController.stream;

  /// Stream emitting active microphone listening state.
  Stream<bool> get isListeningStream => _listeningController.stream;

  bool get isListening => _isListening;
  ThreatDetectorService get detector => _detector;

  /// Initializes the TFLite inference engine.
  Future<void> initialize() async {
    if (!_detector.isInitialized) {
      await _detector.initialize();
    }
  }

  /// Starts continuous 16 kHz 16-bit mono PCM microphone streaming and sliding inference.
  Future<bool> start() async {
    if (_isListening) return true;

    // Check & request microphone permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      debugPrint('[AudioStreamController] Microphone permission denied ($micStatus)');
      return false;
    }

    await initialize();

    try {
      _buffer.clear();

      // Configure raw 16 kHz 16-bit mono PCM recording stream
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: false,
      );

      final audioStream = await _recorder.startStream(config);

      // Ingest PCM byte chunks into sliding circular buffer
      _pcmSubscription = audioStream.listen(
        _onAudioChunkReceived,
        onError: (err) {
          debugPrint('[AudioStreamController] Error in audio stream: $err');
          stop();
        },
        cancelOnError: true,
      );

      // Scheduled 0.5s (500 ms) sliding-window inference timer
      _inferenceTimer = Timer.periodic(const Duration(milliseconds: 500), _runSlidingInference);

      _isListening = true;
      _listeningController.add(true);
      debugPrint('[AudioStreamController] Real-time audio inference loop started (16 kHz, 0.5s sliding window).');
      return true;
    } catch (e, stack) {
      debugPrint('[AudioStreamController] Failed to start audio stream: $e\n$stack');
      await stop();
      return false;
    }
  }

  /// Converts raw 16-bit little-endian PCM bytes into normalized [-1.0, 1.0] Float32 samples.
  void _onAudioChunkReceived(Uint8List chunk) {
    if (chunk.isEmpty) return;

    final byteData = ByteData.sublistView(chunk);
    final sampleCount = byteData.lengthInBytes ~/ 2;
    if (sampleCount == 0) return;

    final floatSamples = Float32List(sampleCount);
    for (int i = 0; i < sampleCount; i++) {
      final sampleInt16 = byteData.getInt16(i * 2, Endian.little);
      // Normalize to [-1.0, 1.0]
      floatSamples[i] = sampleInt16 / 32768.0;
    }

    _buffer.writeSamples(floatSamples);
  }

  /// Scheduled every 500ms: takes a 15,600-sample snapshot and evaluates threat probabilities.
  Future<void> _runSlidingInference(Timer _) async {
    if (!_buffer.isFull || _isProcessingInference) return;

    _isProcessingInference = true;
    try {
      final windowSnapshot = _buffer.snapshot();
      final threat = await _detector.predict(windowSnapshot);

      if (threat != null) {
        debugPrint('[AudioStreamController] ⚠️ THREAT DETECTED: $threat');
        _threatController.add(threat);
      }
    } catch (e) {
      debugPrint('[AudioStreamController] Error during sliding inference: $e');
    } finally {
      _isProcessingInference = false;
    }
  }

  /// Logs a false alarm, applying a 95% threshold backoff for 15 minutes.
  void recordFalseAlarm() {
    _detector.recordFalseAlarm();
  }

  /// Stops continuous microphone capture and pauses inference.
  Future<void> stop() async {
    if (!_isListening) return;

    _inferenceTimer?.cancel();
    _inferenceTimer = null;

    await _pcmSubscription?.cancel();
    _pcmSubscription = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    _isListening = false;
    _isProcessingInference = false;
    _buffer.clear();
    _listeningController.add(false);

    debugPrint('[AudioStreamController] Real-time audio inference stopped.');
  }

  void dispose() {
    stop();
    _detector.dispose();
    _threatController.close();
    _listeningController.close();
    _recorder.dispose();
  }
}
