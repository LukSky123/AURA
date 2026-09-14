import 'package:flutter/material.dart';
import '../../domain.dart';
import '../../services/onboarding_storage.dart';
import '../../theme/aura_theme.dart';
import 'screen1_privacy.dart';
import 'screen2_permissions.dart';
import 'screen3_contacts.dart';
import 'screen4_calibration.dart';
import 'screen5_drill.dart';
import 'screen6_paywall.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.onCompleted,
    this.initialContacts = const [],
  });

  final void Function(List<TrustedContact> contacts, SubscriptionTier tier) onCompleted;
  final List<TrustedContact> initialContacts;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<TrustedContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _contacts = List.from(widget.initialContacts);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 5) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleComplete(SubscriptionTier tier) async {
    await OnboardingStorage.saveContacts(_contacts);
    await OnboardingStorage.setCompletedOnboarding(true);
    widget.onCompleted(_contacts, tier);
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_currentPage + 1) / 6.0;

    return Scaffold(
      backgroundColor: AuraColors.background,
      appBar: AppBar(
        backgroundColor: AuraColors.background,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: _previousPage,
              )
            : null,
        title: Column(
          children: [
            Text(
              'STEP ${_currentPage + 1} OF 6',
              style: const TextStyle(
                color: AuraColors.cyan,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 140,
                height: 4,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(AuraColors.cyan),
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) => setState(() => _currentPage = page),
        children: [
          Screen1Privacy(onNext: _nextPage),
          Screen2Permissions(onNext: _nextPage),
          Screen3Contacts(
            initialContacts: _contacts,
            onNext: (updatedContacts) {
              setState(() => _contacts = updatedContacts);
              _nextPage();
            },
          ),
          Screen4Calibration(onNext: _nextPage),
          Screen5Drill(onNext: _nextPage),
          Screen6Paywall(onFinish: _handleComplete),
        ],
      ),
    );
  }
}
