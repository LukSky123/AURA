import 'package:flutter/material.dart';
import '../domain.dart';
import '../theme/aura_theme.dart';

class RecentsTab extends StatelessWidget {
  const RecentsTab({
    super.key,
    required this.history,
  });

  final List<Incident> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AuraColors.surface,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 44,
                  color: AuraColors.cyan,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Incidents Detected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Acoustic threats and manual SOS triggers will appear here in chronological order.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AuraColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = history[index];
        final bool isCancelled = item.status == IncidentStatus.cancelled;
        final Color accent = isCancelled
            ? AuraColors.cyan
            : switch (item.kind) {
                IncidentKind.gunshot => AuraColors.crimson,
                IncidentKind.explosion => AuraColors.crimson,
                IncidentKind.glassBreak => Colors.orangeAccent,
                _ => AuraColors.crimson,
              };

        final String title = isCancelled
            ? 'False Alarm Dismissed'
            : switch (item.kind) {
                IncidentKind.gunshot => 'Gunshot Detected',
                IncidentKind.explosion => 'Explosion Signature',
                IncidentKind.glassBreak => 'Glass Breakage',
                IncidentKind.collision => 'Collision Impact',
                IncidentKind.manualSos => 'Manual SOS Duress',
              };

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AuraColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accent.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          item.kind.name.toUpperCase(),
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (item.confidence != null)
                        Text(
                          '${(item.confidence! * 100).round()}% Confidence',
                          style: const TextStyle(
                            color: AuraColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: AuraColors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    item.smsDispatchMode == SmsDispatchMode.cloudTermii
                        ? Icons.cloud_done_rounded
                        : Icons.sim_card_rounded,
                    size: 14,
                    color: AuraColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.smsDispatchMode == SmsDispatchMode.cloudTermii
                        ? 'Cloud Termii SMS'
                        : 'Local Carrier SIM SMS',
                    style: const TextStyle(
                      color: AuraColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  if (item.latitude != null && item.longitude != null) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined, size: 14, color: AuraColors.cyan),
                    const SizedBox(width: 2),
                    Text(
                      '${item.latitude!.toStringAsFixed(3)}, ${item.longitude!.toStringAsFixed(3)}',
                      style: const TextStyle(
                        color: AuraColors.cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
