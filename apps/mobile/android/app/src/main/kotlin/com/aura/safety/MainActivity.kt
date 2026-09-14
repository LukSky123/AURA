package com.aura.safety

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.telephony.SmsManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var detectionEventSink: EventChannel.EventSink? = null
    private var hardwareEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Native controls channel (SMS, Accessibility, Battery Optimizations, Background Service)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aura.safety/native_controls")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendDirectSms" -> {
                        val phone = call.argument<String>("phoneNumber")
                        val message = call.argument<String>("message")
                        if (phone.isNullOrBlank() || message.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENTS", "Phone number and message must not be empty", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                getSystemService(SmsManager::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getDefault()
                            }
                            val parts = smsManager.divideMessage(message)
                            if (parts.size > 1) {
                                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                            } else {
                                smsManager.sendTextMessage(phone, null, message, null, null)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SMS_FAILED", e.message, null)
                        }
                    }
                    "isAccessibilityEnabled" -> {
                        val expectedComponentName = ComponentName(this, AuraAccessibilityService::class.java).flattenToString()
                        val enabledServices = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
                        val isEnabled = enabledServices.split(':').any {
                            it.equals(expectedComponentName, ignoreCase = true) ||
                            it.equals("${packageName}/.AuraAccessibilityService", ignoreCase = true)
                        }
                        result.success(isEnabled)
                    }
                    "openAccessibilitySettings" -> {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    }
                    "isBatteryOptimizationIgnored" -> {
                        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                        val isIgnored = powerManager.isIgnoringBatteryOptimizations(packageName)
                        result.success(isIgnored)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    }
                    "startForegroundService" -> {
                        ContextCompat.startForegroundService(this, Intent(this, AudioDetectionService::class.java))
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        stopService(Intent(this, AudioDetectionService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Hardware volume key events stream channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aura.safety/hardware_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    hardwareEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    hardwareEventSink = null
                }
            })

        // Safety shortcut bus listener dispatching to Flutter UI thread
        SafetyShortcutBus.listener = { eventName ->
            runOnUiThread {
                hardwareEventSink?.success(eventName)
            }
        }

        // Backward compatibility for detection service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aura.safety/detection")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        ContextCompat.startForegroundService(this, Intent(this, AudioDetectionService::class.java))
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, AudioDetectionService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aura.safety/detection-events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    detectionEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    detectionEventSink = null
                }
            })

        DetectionBus.listener = { prediction ->
            runOnUiThread {
                detectionEventSink?.success(mapOf("kind" to prediction.kind, "confidence" to prediction.confidence))
            }
        }
    }
}
