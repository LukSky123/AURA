import 'package:flutter/material.dart';
import '../domain.dart';
import '../theme/aura_theme.dart';

class ThreatAlertOverlay extends StatelessWidget {
  const ThreatAlertOverlay({
    super.key,
    required this.incident,
    required this.remainingSeconds,
    required this.onDispatchNow,
    required this.onCancel,
  });

  final Incident incident;
  final int remainingSeconds;
  final VoidCallback onDispatchNow;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final double progress = (remainingSeconds / 20.0).clamp(0.0, 1.0);
    final String kindLabel = switch (incident.kind) {
      IncidentKind.gunshot => 'GUNSHOT',
      IncidentKind.glassBreak => 'GLASS BREAK',
      IncidentKind.collision => 'COLLISION',
      IncidentKind.explosion => 'EXPLOSION',
      IncidentKind.manualSos => 'MANUAL SOS',
    };
    final String confidenceText = incident.confidence != null
        ? '${(incident.confidence! * 100).round()}% MATCH'
        : 'MANUAL TRIGGER';

    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AuraColors.crimson.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AuraColors.crimson.withValues(alpha: 0.35),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Header
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AuraColors.crimson,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CRITICAL THREAT DETECTED',
                        style: TextStyle(
                          color: AuraColors.crimson,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: AuraColors.crimsonContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AuraColors.crimson.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '$kindLabel • $confidenceText',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),

              // Central Threat Visual with concentric red ripple
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AuraColors.crimson.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AuraColors.crimson.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                  ),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AuraColors.crimsonContainer,
                      boxShadow: [
                        BoxShadow(
                          color: AuraColors.crimson.withValues(alpha: 0.6),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.crisis_alert_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                  ),
                ],
              ),

              // Countdown Gauge
              Column(
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          color: AuraColors.crimson,
                        ),
                        Text(
                          '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Sending SOS to trusted contacts in s...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AuraColors.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Action Buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: onDispatchNow,
                      icon: const Icon(Icons.sos_rounded, color: Colors.white, size: 24),
                      label: const Text(
                        'SEND SOS NOW VIA SMS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AuraColors.crimson,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 10,
                        shadowColor: AuraColors.crimson.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.check_circle_outline, color: AuraColors.onSurfaceVariant),
                      label: const Text(
                        'FALSE ALARM — I''M SAFE',
                        style: TextStyle(
                          color: AuraColors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.8,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.volume_up, size: 14, color: AuraColors.onSurfaceVariant.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        'Double Vol Up: SOS • Vol Down: Cancel',
                        style: TextStyle(
                          color: AuraColors.onSurfaceVariant.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
