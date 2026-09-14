package com.aura.safety

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.KeyEvent

/**
 * Android Accessibility Service for AURA.
 * Intercepts Volume Up double-press (instant dispatch) and Volume Down double-press (cancel).
 * Single presses are passed through so standard volume adjustment is never blocked.
 * Enabled only through Android Accessibility settings with informed user consent.
 */
class AuraAccessibilityService : AccessibilityService() {
    private var lastVolumeUpTime = 0L
    private var lastVolumeDownTime = 0L

    override fun onAccessibilityEvent(event: android.view.accessibility.AccessibilityEvent?) = Unit
    override fun onInterrupt() = Unit

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.action != KeyEvent.ACTION_DOWN) return false
        val now = event.eventTime

        return when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                if (now - lastVolumeUpTime < DOUBLE_PRESS_WINDOW_MS) {
                    lastVolumeUpTime = 0L
                    SafetyShortcutBus.instantDispatch()
                    true // Consume event: triggers instant emergency dispatch
                } else {
                    lastVolumeUpTime = now
                    false // Pass through to allow volume adjustment on single press
                }
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                if (now - lastVolumeDownTime < DOUBLE_PRESS_WINDOW_MS) {
                    lastVolumeDownTime = 0L
                    SafetyShortcutBus.cancelCountdown()
                    true // Consume event: cancels countdown
                } else {
                    lastVolumeDownTime = now
                    false // Pass through to allow volume adjustment on single press
                }
            }
            else -> false
        }
    }

    companion object {
        private const val DOUBLE_PRESS_WINDOW_MS = 650L
    }
}

object SafetyShortcutBus {
    var listener: ((String) -> Unit)? = null

    fun instantDispatch() {
        listener?.invoke("instant_dispatch")
    }

    fun cancelCountdown() {
        listener?.invoke("cancel_countdown")
    }
}
