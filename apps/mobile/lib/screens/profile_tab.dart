import 'package:flutter/material.dart';
import '../domain.dart';
import '../services/entitlement_service.dart';
import '../theme/aura_theme.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.entitlementService,
    required this.contacts,
    required this.accessibilityEnabled,
    required this.batteryOptimizationIgnored,
    required this.optInAudioDonation,
    required this.onAddContact,
    required this.onShowUpgradePaywall,
    required this.onToggleAudioDonation,
    required this.onOpenAccessibilitySettings,
    required this.onRequestIgnoreBattery,
    required this.onShowPrivacy,
  });

  final EntitlementService entitlementService;
  final List<TrustedContact> contacts;
  final bool accessibilityEnabled;
  final bool batteryOptimizationIgnored;
  final bool optInAudioDonation;
  final VoidCallback onAddContact;
  final VoidCallback onShowUpgradePaywall;
  final ValueChanged<bool> onToggleAudioDonation;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback onRequestIgnoreBattery;
  final VoidCallback onShowPrivacy;

  @override
  Widget build(BuildContext context) {
    final currentTier = entitlementService.entitlements.value.tier;
    final maxContacts = entitlementService.entitlements.value.contactLimit;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Subscription Tier Glass Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AuraColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: currentTier == SubscriptionTier.free
                  ? Colors.white.withValues(alpha: 0.1)
                  : AuraColors.cyan.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: (currentTier == SubscriptionTier.free
                        ? Colors.black
                        : AuraColors.cyan)
                    .withValues(alpha: 0.15),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        color: currentTier == SubscriptionTier.free
                            ? Colors.grey
                            : AuraColors.cyan,
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        switch (currentTier) {
                          SubscriptionTier.free => 'AURA Free Tier',
                          SubscriptionTier.pro => 'AURA Pro Member',
                          SubscriptionTier.family => 'AURA Family Circle',
                        },
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: onShowUpgradePaywall,
                    style: TextButton.styleFrom(
                      foregroundColor: AuraColors.cyan,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: Text(
                      currentTier == SubscriptionTier.free ? 'UPGRADE' : 'MANAGE',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                switch (currentTier) {
                  SubscriptionTier.free =>
                    'Local edge AI audio classification + carrier SIM SMS alerts to up to 2 emergency contacts.',
                  SubscriptionTier.pro =>
                    'Unlimited automated cloud Termii SMS, 5 emergency contacts, and live responder map tracking.',
                  SubscriptionTier.family =>
                    '5 linked family accounts, shared transit timers, and circle siren emergency triggers.',
                },
                style: const TextStyle(
                  color: AuraColors.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Diaspora Sponsorship Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AuraColors.surfaceLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AuraColors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.public_rounded, color: AuraColors.cyan, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Diaspora Sponsorship',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Loved ones abroad (US, UK, CA) can fund your safety plan via Paystack.',
                      style: TextStyle(
                        color: AuraColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Trusted Contacts Header & Counter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trusted Contacts (${contacts.length}/$maxContacts)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (contacts.length < maxContacts)
              IconButton(
                onPressed: onAddContact,
                icon: const Icon(Icons.person_add_alt_1_rounded, color: AuraColors.cyan, size: 20),
                tooltip: 'Add Contact',
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Contacts List
        ...contacts.map((contact) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AuraColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AuraColors.cyan.withValues(alpha: 0.15),
                  child: Text(
                    contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: AuraColors.cyan, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        contact.phone,
                        style: const TextStyle(color: AuraColors.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.verified_rounded, color: AuraColors.cyan, size: 18),
              ],
            ),
          );
        }),

        const SizedBox(height: 24),

        // Device Diagnostics & Hardware Shortcuts
        const Text(
          'Hardware & Resilience Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
            color: AuraColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              ListTile(
                title: const Text('Double Vol Up SOS Shortcut', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(
                  accessibilityEnabled ? 'Accessibility Service active' : 'Tap to enable in Android settings',
                  style: TextStyle(
                    color: accessibilityEnabled ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  accessibilityEnabled ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: accessibilityEnabled ? Colors.greenAccent : Colors.orangeAccent,
                  size: 20,
                ),
                onTap: onOpenAccessibilitySettings,
              ),
              const Divider(height: 1, color: Colors.white12),
              ListTile(
                title: const Text('Background Battery Persistence', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(
                  batteryOptimizationIgnored ? 'Exempt from power throttling' : 'Tap to whitelist AURA',
                  style: TextStyle(
                    color: batteryOptimizationIgnored ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  batteryOptimizationIgnored ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: batteryOptimizationIgnored ? Colors.greenAccent : Colors.orangeAccent,
                  size: 20,
                ),
                onTap: onRequestIgnoreBattery,
              ),
              const Divider(height: 1, color: Colors.white12),
              SwitchListTile(
                title: const Text('Contribute False-Alarm Audio', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text(
                  'Upload 3s encrypted sample on dismissal to improve African acoustic models.',
                  style: TextStyle(color: AuraColors.onSurfaceVariant, fontSize: 11),
                ),
                value: optInAudioDonation,
                activeThumbColor: AuraColors.cyan,
                onChanged: onToggleAudioDonation,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Privacy Policy Link
        Center(
          child: TextButton.icon(
            onPressed: onShowPrivacy,
            icon: const Icon(Icons.privacy_tip_outlined, color: AuraColors.onSurfaceVariant, size: 16),
            label: const Text(
              'Privacy Architecture & Terms',
              style: TextStyle(color: AuraColors.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
