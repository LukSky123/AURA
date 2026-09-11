package com.aura.safety

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.IBinder
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*

/**
 * Visible Android-only foreground audio service. PCM remains in memory; this
 * service never writes ambient audio to disk. ModelRunner must be wired to the
 * versioned, INT8 model only after its release gates pass.
 */
class AudioDetectionService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var recorder: AudioRecord? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, notification())
        scope.launch { captureLoop() }
        return START_STICKY
    }

    private suspend fun captureLoop() {
        val sampleRate = 16_000
        val minBuffer = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (minBuffer <= 0) return
        recorder = AudioRecord(MediaRecorder.AudioSource.DEFAULT, sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, minBuffer * 4)
        val buffer = ShortArray(sampleRate) // One second rolling inference window.
        recorder?.startRecording()
        while (currentCoroutineContext().isActive) {
            val read = recorder?.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING) ?: 0
            if (read > 0) {
                // Intentionally no raw-audio persistence. NativeModelRunner publishes
                // only label/confidence through the Flutter event channel.
                NativeModelRunner.score(buffer.copyOf(read))?.let { DetectionBus.publish(it) }
            }
        }
    }

    override fun onDestroy() { recorder?.stop(); recorder?.release(); recorder = null; scope.cancel(); super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null

    private fun notification(): Notification {
        val channel = NotificationChannel(CHANNEL_ID, "AURA protection", NotificationManager.IMPORTANCE_LOW)
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        return NotificationCompat.Builder(this, CHANNEL_ID).setSmallIcon(android.R.drawable.ic_dialog_alert).setContentTitle("AURA protection is active").setContentText("Listening for urgent danger sounds").setOngoing(true).build()
    }
    companion object { const val CHANNEL_ID = "aura_protection"; const val NOTIFICATION_ID = 2101 }
}

data class NativePrediction(val kind: String, val confidence: Float)
object NativeModelRunner {
    fun score(samples: ShortArray): NativePrediction? = null // Loaded only from a released model manifest.
}
object DetectionBus {
    var listener: ((NativePrediction) -> Unit)? = null
    fun publish(prediction: NativePrediction) { listener?.invoke(prediction) }
}
