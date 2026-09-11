import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_sound/flutter_sound.dart';

import '../classifier.dart';

// ----------------------------------------------------------------------------
// Foreground Service Entry Point
// Must be a top-level function marked with @pragma('vm:entry-point').
// ----------------------------------------------------------------------------

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(AuraTaskHandler());
}

// ----------------------------------------------------------------------------
// Task Handler — runs in isolate
// ----------------------------------------------------------------------------

class AuraTaskHandler extends TaskHandler {
  // 🎤 Recorder
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  // 📡 Audio stream controller
  final StreamController<Uint8List> _audioStreamController =
      StreamController<Uint8List>();

  // 🧠 Rolling audio buffer & prediction history
  final List<int> _audioBuffer = [];
  final List<String> _predictionHistory = [];

  late AudioClassifier _classifier;

  static const int sampleRate = 16000;
  static const int bytesPerSample = 2; // PCM16
  static const int targetSeconds = 1;
  final int targetBytes = sampleRate * bytesPerSample * targetSeconds;

  // --------------------------------------------------------------------------
  // Lifecycle
  // --------------------------------------------------------------------------

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('🚀 AURA Foreground Service: onStart');

    _classifier = AudioClassifier();
    await _classifier.loadModel();

    await _initRecorder();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Audio is processed continuously via stream; nothing extra needed here.
    // This callback fires every 1000ms (set in ForegroundTaskEventAction.repeat).
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('🛑 AURA Foreground Service: onDestroy');
    await _recorder.stopRecorder();
    await _recorder.closeRecorder();
    await _audioStreamController.close();
  }

  // --------------------------------------------------------------------------
  // Recorder setup
  // --------------------------------------------------------------------------

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();

    // 🎧 Listen to incoming PCM audio
    _audioStreamController.stream.listen((buffer) async {
      _audioBuffer.addAll(buffer);

      if (_audioBuffer.length >= targetBytes) {
        // Take exactly 1 second of audio
        final Uint8List oneSecondAudioBytes = Uint8List.fromList(
          _audioBuffer.sublist(0, targetBytes),
        );

        // Remove used bytes (rolling buffer)
        _audioBuffer.removeRange(0, targetBytes);

        // Convert bytes to Float32 [-1.0, 1.0]
        final Float32List audioFloats = _bytesToFloat(oneSecondAudioBytes);

        await _processAudioBuffer(audioFloats);
      }
    });

    // ▶️ Start recording into the stream
    await _recorder.startRecorder(
      toStream: _audioStreamController.sink,
      codec: Codec.pcm16,
      sampleRate: sampleRate,
      numChannels: 1,
    );
  }

  // --------------------------------------------------------------------------
  // Inference pipeline
  // --------------------------------------------------------------------------

  Future<void> _processAudioBuffer(Float32List audioFloats) async {
    // 1. 🛡️ Silence / Energy Gate
    final double energy = _calculateEnergy(audioFloats);
    if (energy < 0.0005) {
      debugPrint(
        "Service: Silence (Energy: ${energy.toStringAsFixed(6)}), skipping.",
      );
      return;
    }

    // Run Inference
    final result = await _classifier.predict(audioFloats);
    String label = result['label'];
    final double confidence = result['confidence'];

    // 2. 🛡️ Confidence Threshold
    if (confidence < 0.85) {
      debugPrint("Service: Low confidence ($confidence < 0.85), ignoring.");
      return;
    }

    // 3. 🛡️ Glass vs Gunshot Heuristic
    if (label == 'Gunshot' && energy < 0.002) {
      debugPrint("Service: Downgraded Gunshot → Glass (energy < 0.002).");
      label = 'Glass';
    }

    // 4. 🛡️ Temporal Consensus (Anti-False Alarm)
    _predictionHistory.add(label);
    if (_predictionHistory.length > 3) {
      _predictionHistory.removeAt(0);
    }

    final int matchCount = _predictionHistory.where((l) => l == label).length;
    final bool confirmed = matchCount >= 2;

    if (confirmed) {
      debugPrint(
        "Service: CONFIRMED: $label → ${confidence.toStringAsFixed(2)}",
      );

      // Send data back to UI isolate (if app is open)
      FlutterForegroundTask.sendDataToMain({
        'label': label,
        'confidence': confidence,
      });

      // Show alert notification
      _triggerAlertNotification(label);
    }
  }

  // --------------------------------------------------------------------------
  // Alert Notification
  // --------------------------------------------------------------------------

  void _triggerAlertNotification(String label) {
    if (label == 'Gunshot') {
      FlutterForegroundTask.updateService(
        notificationTitle: 'AURA Alert',
        notificationText:
            'Possible gunshots detected nearby. Leave the area immediately.',
      );
    } else if (label == 'Glass') {
      FlutterForegroundTask.updateService(
        notificationTitle: 'AURA Alert',
        notificationText: 'Glass breaking detected nearby. Stay alert.',
      );
    }
  }

  // --------------------------------------------------------------------------
  // Helper Methods
  // --------------------------------------------------------------------------

  double _calculateEnergy(Float32List samples) {
    double energy = 0;
    for (final s in samples) {
      energy += s * s;
    }
    return energy / samples.length;
  }

  Float32List _bytesToFloat(Uint8List bytes) {
    final floats = Float32List(bytes.length ~/ 2);
    final byteData = bytes.buffer.asByteData();
    for (int i = 0; i < bytes.length; i += 2) {
      final int sample = byteData.getInt16(i, Endian.little);
      floats[i ~/ 2] = sample / 32768.0;
    }
    return floats;
  }
}

// ----------------------------------------------------------------------------
// External Service API
// ----------------------------------------------------------------------------

void initAuraService() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'aura_alert_channel',
      channelName: 'AURA Alerts',
      channelDescription: 'Continuous audio listening for AURA',
      channelImportance: NotificationChannelImportance.DEFAULT,
      priority: NotificationPriority.DEFAULT,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      // Fire onRepeatEvent every second for the loop
      eventAction: ForegroundTaskEventAction.repeat(1000),
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

Future<void> startAuraService() async {
  if (await FlutterForegroundTask.isRunningService) {
    return;
  }

  await FlutterForegroundTask.startService(
    notificationTitle: 'AURA Active',
    notificationText: 'Listening for dangerous sounds',
    callback: startCallback,
  );
}

Future<void> stopAuraService() async {
  await FlutterForegroundTask.stopService();
}
