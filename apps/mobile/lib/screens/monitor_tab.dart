import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';
import '../widgets/radar_visualizer.dart';

class MonitorTab extends StatelessWidget {
  const MonitorTab({
    super.key,
    required this.isListening,
    required this.isDynamicBackoffActive,
    required this.accessibilityEnabled,
    required this.batteryOptimizationIgnored,
    required this.onToggleListening,
    required this.onInstantSos,
    required this.onOpenAccessibilitySettings,
    required this.onRequestIgnoreBattery,
  });

  final bool isListening;
  final bool isDynamicBackoffActive;
  final bool accessibilityEnabled;
  final bool batteryOptimizationIgnored;
  final VoidCallback onToggleListening;
  final VoidCallback onInstantSos;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback onRequestIgnoreBattery;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // Readiness Warning Banner (if hardware accessibility or battery whitelist are missing)
          if (!accessibilityEnabled || !batteryOptimizationIgnored) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Device Setup Recommended',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'To enable covert double-press Volume Up panic alerts when locked, enable the AURA Accessibility Service.',
                    style: TextStyle(color: AuraColors.onSurfaceVariant, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (!accessibilityEnabled)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onOpenAccessibilitySettings,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Enable Volume SOS', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      if (!accessibilityEnabled && !batteryOptimizationIgnored)
                        const SizedBox(width: 8),
                      if (!batteryOptimizationIgnored)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onRequestIgnoreBattery,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: const Text('Whitelist Battery', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 10),

          // Central Animated Radar Visualizer
          RadarVisualizer(
            isListening: isListening,
            onToggle: onToggleListening,
            statusText: isDynamicBackoffActive
                ? 'Backoff Active: Scanning with 95% threshold (15m)'
                : 'Acoustic Aura Active: Scanning 16 kHz ambient window',
          ),

          const SizedBox(height: 28),

          // Threat Detection Telemetry Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AuraColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isListening ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                          color: isListening ? AuraColors.cyan : AuraColors.onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Acoustic Neural Engine',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isListening ? AuraColors.cyan : Colors.grey)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isListening ? 'LIVE' : 'STANDBY',
                        style: TextStyle(
                          color: isListening ? AuraColors.cyan : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TelemetryMetric(
                        label: 'Model Architecture',
                        value: 'YAMNet 4-Class',
                        subtext: 'Quantized INT8',
                      ),
                    ),
                    Container(width: 1, height: 36, color: Colors.white12),
                    Expanded(
                      child: _TelemetryMetric(
                        label: 'Sensitivity Barrier',
                        value: isDynamicBackoffActive ? '95%' : '80%',
                        subtext: isDynamicBackoffActive ? 'Backoff Mode' : 'Baseline Mode',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Instant SOS Duress Panic Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onInstantSos,
              icon: const Icon(Icons.sos_rounded, color: Colors.white, size: 26),
              label: const Text(
                'INSTANT SOS DURESS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AuraColors.crimson,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: AuraColors.crimson.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Covert shortcut: Double-press Volume Up button anytime',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AuraColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TelemetryMetric extends StatelessWidget {
  const _TelemetryMetric({
    required this.label,
    required this.value,
    required this.subtext,
  });

  final String label;
  final String value;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AuraColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          subtext,
          style: TextStyle(
            color: AuraColors.cyan.withValues(alpha: 0.8),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
