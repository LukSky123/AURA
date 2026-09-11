import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'services/aura_foreground_service.dart';

void main() {
  // Initialize flutter_foreground_task
  FlutterForegroundTask.initCommunicationPort();
  runApp(const AuraApp());
}

class AuraApp extends StatefulWidget {
  const AuraApp({super.key});

  @override
  State<AuraApp> createState() => _AuraAppState();
}

class _AuraAppState extends State<AuraApp> {
  bool _isListening = false;
  String _latestPrediction = "Ready...";
  double _latestConfidence = 0.0;

  @override
  void initState() {
    super.initState();
    _initServiceParams();
  }

  void _initServiceParams() {
    initAuraService();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.notification.request();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await stopAuraService();
      setState(() {
        _isListening = false;
        _latestPrediction = "Stopped";
        _latestConfidence = 0.0;
      });
    } else {
      await _requestPermissions();
      await startAuraService();
      setState(() {
        _isListening = true;
        _latestPrediction = "Listening in Background...";
      });
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
  }

  void _onReceiveTaskData(Object data) {
    // Optional: receive data from the service isolate to update UI if open
    if (data is Map) {
      setState(() {
        _latestPrediction = data['label'] ?? '';
        _latestConfidence = data['confidence'] ?? 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: WithForegroundTask(
        child: Scaffold(
          appBar: AppBar(title: const Text('AURA Detection')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isListening ? 'AURA Service Active' : 'AURA Service Stopped',
                  style: TextStyle(
                    fontSize: 18,
                    color: _isListening ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _toggleListening,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening ? Colors.red : Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 20,
                    ),
                  ),
                  child: Text(
                    _isListening ? "Stop Listening" : "Start Listening",
                    style: const TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 50),
                if (_isListening) ...[
                  const Text(
                    'Latest Detection (if open):',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _latestPrediction,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (_isListening && _latestConfidence > 0)
                  Text(
                    "Confidence: ${(_latestConfidence * 100).toStringAsFixed(1)}%",
                    style: const TextStyle(fontSize: 16),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
