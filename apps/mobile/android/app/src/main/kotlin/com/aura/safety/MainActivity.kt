package com.aura.safety

import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aura.safety/detection")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> { ContextCompat.startForegroundService(this, Intent(this, AudioDetectionService::class.java)); result.success(null) }
                    "stop" -> { stopService(Intent(this, AudioDetectionService::class.java)); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aura.safety/detection-events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
                override fun onCancel(arguments: Any?) { eventSink = null }
            })
        DetectionBus.listener = { prediction -> runOnUiThread { eventSink?.success(mapOf("kind" to prediction.kind, "confidence" to prediction.confidence)) } }
    }
}
