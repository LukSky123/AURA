import 'package:flutter/material.dart';
import '../../theme/aura_theme.dart';

class Screen1Privacy extends StatelessWidget {
  const Screen1Privacy({
    super.key,
    required this.onNext,
  });

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Visual Aura Shield
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AuraColors.surface,
                        border: Border.all(
                          color: AuraColors.cyan.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AuraColors.cyan.withValues(alpha: 0.25),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock_outline_rounded,
                          color: AuraColors.cyan,
                          size: 54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Header
                    const Text(
                      'Zero-Cloud Privacy Promise',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AURA runs 100% on your device. Your private conversations never leave this phone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AuraColors.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Key Guarantees
                    _PrivacyBullet(
                      icon: Icons.memory_rounded,
                      title: 'Volatile RAM-Only Inference',
                      description:
                          'Acoustics are scanned in rolling 0.975-second (15,600 sample) windows strictly inside temporary RAM buffers.',
                    ),
                    const SizedBox(height: 14),
                    _PrivacyBullet(
                      icon: Icons.cloud_off_rounded,
                      title: 'Zero Cloud Audio Uploads',
                      description:
                          'Audio is never recorded, never stored on disk, and never streamed to any remote server or third party.',
                    ),
                    const SizedBox(height: 14),
                    _PrivacyBullet(
                      icon: Icons.delete_sweep_rounded,
                      title: 'Instant Ephemeral Purge',
                      description:
                          'Frames not matching danger signatures (gunshots, explosions, glass shatter) are instantly overwritten in memory.',
                    ),
                    const SizedBox(height: 14),
                    _PrivacyBullet(
                      icon: Icons.crisis_alert_rounded,
                      title: 'Threat-Only Emergency Dispatch',
                      description:
                          'Only verified emergency threats initiate GPS and contact notifications via Termii or direct carrier SMS.',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // CTA Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuraColors.cyan,
                  foregroundColor: AuraColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: AuraColors.cyan.withValues(alpha: 0.4),
                ),
                child: const Text(
                  'I UNDERSTAND & ACCEPT',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PrivacyBullet extends StatelessWidget {
  const _PrivacyBullet({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AuraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AuraColors.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AuraColors.cyan, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AuraColors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
