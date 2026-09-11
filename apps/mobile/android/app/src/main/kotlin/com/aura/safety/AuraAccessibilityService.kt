package com.aura.safety

import android.accessibilityservice.AccessibilityService
import android.view.KeyEvent

/** Enabled only through Android Accessibility settings after user education. */
class AuraAccessibilityService : AccessibilityService() {
    private var lastDownAt = 0L
    override fun onAccessibilityEvent(event: android.view.accessibility.AccessibilityEvent?) = Unit
    override fun onInterrupt() = Unit
    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.action != KeyEvent.ACTION_DOWN) return false
        val now = event.eventTime
        return when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> { SafetyShortcutBus.instantDispatch(); true }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                if (now - lastDownAt < 700) { SafetyShortcutBus.cancelCountdown(); lastDownAt = 0; true } else { lastDownAt = now; false }
            }
            else -> false
        }
    }
}
object SafetyShortcutBus { fun instantDispatch() {} ; fun cancelCountdown() {} }
