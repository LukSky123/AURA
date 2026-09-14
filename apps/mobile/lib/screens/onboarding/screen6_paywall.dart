import 'package:flutter/material.dart';
import '../../domain.dart';
import '../../theme/aura_theme.dart';

class Screen6Paywall extends StatefulWidget {
  const Screen6Paywall({
    super.key,
    required this.onFinish,
  });

  final ValueChanged<SubscriptionTier> onFinish;

  @override
  State<Screen6Paywall> createState() => _Screen6PaywallState();
}

class _Screen6PaywallState extends State<Screen6Paywall> {
  SubscriptionTier _selectedTier = SubscriptionTier.pro;

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
                    const SizedBox(height: 12),
                    const Icon(Icons.verified_user_rounded, color: AuraColors.cyan, size: 44),
                    const SizedBox(height: 12),
                    const Text(
                      'Choose Your Protection',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Protect yourself and your loved ones with autonomous acoustic safety.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AuraColors.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Plan 1: Free
                    _OnboardingPlanCard(
                      title: 'AURA Free',
                      price: '₦0 / month',
                      isSelected: _selectedTier == SubscriptionTier.free,
                      onTap: () => setState(() => _selectedTier = SubscriptionTier.free),
                      features: const [
                        '2 trusted emergency contacts',
                        'On-device TFLite acoustic detection',
                        'Direct device carrier SIM SMS fallback',
                        '2 monthly cloud SMS credits',
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Plan 2: Pro (Recommended)
                    _OnboardingPlanCard(
                      title: 'AURA Pro',
                      price: '₦4,000 / month (or ₦36,000 / yr)',
                      isRecommended: true,
                      isSelected: _selectedTier == SubscriptionTier.pro,
                      onTap: () => setState(() => _selectedTier = SubscriptionTier.pro),
                      features: const [
                        '5 enabled emergency contacts',
                        'Unlimited Termii automated cloud SMS',
                        'Live responder map tracking',
                        'Smart transit watch timer (45m)',
                        'Priority background listener persistence',
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Plan 3: Family
                    _OnboardingPlanCard(
                      title: 'AURA Family Circle',
                      price: '₦13,500 / month',
                      isSelected: _selectedTier == SubscriptionTier.family,
                      onTap: () => setState(() => _selectedTier = SubscriptionTier.family),
                      features: const [
                        'Up to 5 linked family member accounts',
                        'All Pro features for each family member',
                        'Circle sirens across circle phones',
                        'Shared family transit watch',
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Paystack Primary CTA & Skip Button
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => widget.onFinish(_selectedTier),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AuraColors.cyan,
                      foregroundColor: AuraColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: AuraColors.cyan.withValues(alpha: 0.4),
                    ),
                    child: Text(
                      _selectedTier == SubscriptionTier.free
                          ? 'CONTINUE WITH FREE TIER'
                          : 'SUBSCRIBE VIA PAYSTACK',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => widget.onFinish(SubscriptionTier.free),
                  child: const Text(
                    'Skip for now (Continue with Free Tier)',
                    style: TextStyle(
                      color: AuraColors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPlanCard extends StatelessWidget {
  const _OnboardingPlanCard({
    required this.title,
    required this.price,
    required this.features,
    required this.isSelected,
    required this.onTap,
    this.isRecommended = false,
  });

  final String title;
  final String price;
  final List<String> features;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AuraColors.surfaceHigh : AuraColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AuraColors.cyan
                : (isRecommended ? Colors.white24 : Colors.white.withValues(alpha: 0.08)),
            width: isSelected ? 2 : 1,
          ),
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
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? AuraColors.cyan : AuraColors.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (isRecommended)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AuraColors.cyan,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'POPULAR',
                      style: TextStyle(
                        color: AuraColors.background,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                price,
                style: TextStyle(
                  color: isSelected ? AuraColors.cyan : AuraColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 13, color: AuraColors.cyan),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(color: AuraColors.onSurfaceVariant, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
