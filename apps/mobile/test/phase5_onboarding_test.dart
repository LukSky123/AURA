import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_mobile/domain.dart';
import 'package:aura_mobile/services/onboarding_storage.dart';
import 'package:aura_mobile/screens/onboarding/screen1_privacy.dart';
import 'package:aura_mobile/screens/onboarding/screen3_contacts.dart';
import 'package:aura_mobile/screens/onboarding/screen5_drill.dart';
import 'package:aura_mobile/screens/onboarding/screen6_paywall.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 - OnboardingStorage Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial onboarding state is false', () async {
      final completed = await OnboardingStorage.hasCompletedOnboarding();
      expect(completed, isFalse);
    });

    test('Setting onboarding completion flag persists correctly', () async {
      await OnboardingStorage.setCompletedOnboarding(true);
      final completed = await OnboardingStorage.hasCompletedOnboarding();
      expect(completed, isTrue);

      await OnboardingStorage.resetOnboarding();
      final resetState = await OnboardingStorage.hasCompletedOnboarding();
      expect(resetState, isFalse);
    });

    test('Persisting and loading emergency contacts', () async {
      final sampleContacts = [
        const TrustedContact(id: 'c1', name: 'Amina Bello', phone: '+2348012345678'),
        const TrustedContact(id: 'c2', name: 'Chidi Okafor', phone: '+2348098765432'),
      ];

      await OnboardingStorage.saveContacts(sampleContacts);
      final loaded = await OnboardingStorage.loadContacts();

      expect(loaded.length, 2);
      expect(loaded[0].name, 'Amina Bello');
      expect(loaded[0].phone, '+2348012345678');
      expect(loaded[1].name, 'Chidi Okafor');
      expect(loaded[1].phone, '+2348098765432');
    });
  });

  group('Phase 5 - Screen1Privacy Widget Tests', () {
    testWidgets('Renders zero-cloud privacy promise and accepts', (tester) async {
      bool nextCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Screen1Privacy(
              onNext: () {
                nextCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Zero-Cloud Privacy Promise'), findsOneWidget);
      expect(find.text('Volatile RAM-Only Inference'), findsOneWidget);
      expect(find.text('Zero Cloud Audio Uploads'), findsOneWidget);

      final acceptBtn = find.text('I UNDERSTAND & ACCEPT');
      expect(acceptBtn, findsOneWidget);

      await tester.tap(acceptBtn);
      await tester.pumpAndSettle();

      expect(nextCalled, isTrue);
    });
  });

  group('Phase 5 - Screen3Contacts Hard-Block Widget Tests', () {
    testWidgets('Empty contacts blocks Continue button; adding contact unblocks it', (tester) async {
      List<TrustedContact>? submittedContacts;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Screen3Contacts(
              initialContacts: const [],
              onNext: (contacts) {
                submittedContacts = contacts;
              },
            ),
          ),
        ),
      );

      // Verify requirement warning banner is shown
      expect(find.text('Required: You must add at least 1 emergency contact to activate protection.'), findsOneWidget);

      // Verify Continue button is disabled
      final continueBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'CONTINUE'));
      expect(continueBtn.onPressed, isNull);

      // Fill in contact info
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), 'Dr. Danladi');
      await tester.enterText(textFields.at(1), '+2348033334444');
      await tester.pump();

      // Tap Add Contact
      final addBtn = find.text('ADD TO EMERGENCY CIRCLE');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Verify contact was added and banner shows active status
      expect(find.text('Dr. Danladi'), findsOneWidget);
      expect(find.text('Circle active: 1 of 2 contacts configured (Free tier).'), findsOneWidget);

      // Verify Continue button is now enabled
      final enabledBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'CONTINUE'));
      expect(enabledBtn.onPressed, isNotNull);

      // Tap Continue
      await tester.tap(find.widgetWithText(ElevatedButton, 'CONTINUE'));
      await tester.pumpAndSettle();

      expect(submittedContacts, isNotNull);
      expect(submittedContacts!.length, 1);
      expect(submittedContacts!.first.name, 'Dr. Danladi');
    });

    testWidgets('Free tier restricts to 2 contacts and triggers Pro upsell', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Screen3Contacts(
              initialContacts: const [
                TrustedContact(id: '1', name: 'Contact One', phone: '+2348000000001'),
                TrustedContact(id: '2', name: 'Contact Two', phone: '+2348000000002'),
              ],
              onNext: (_) {},
            ),
          ),
        ),
      );

      // 2 contacts configured
      expect(find.text('Circle active: 2 of 2 contacts configured (Free tier).'), findsOneWidget);
      expect(find.text('AURA Pro Supports 5 Contacts'), findsOneWidget);
    });
  });

  group('Phase 5 - Screen5Drill Widget Tests', () {
    testWidgets('Displays simulated drill banner and 2s disarm action', (tester) async {
      bool drillFinished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Screen5Drill(
              onNext: () {
                drillFinished = true;
              },
            ),
          ),
        ),
      );

      // Verify safety banner
      expect(find.text('DRILL MODE — REAL SMS STRICTLY BYPASSED'), findsOneWidget);
      expect(find.text('SIMULATED THREAT DRILL'), findsOneWidget);
      expect(find.text('HOLD 2 SECONDS TO DISARM'), findsOneWidget);

      // Perform long press / hold to disarm
      final gesture = await tester.startGesture(tester.getCenter(find.text('HOLD 2 SECONDS TO DISARM')));
      await tester.pump();
      // Advance by 2.2 seconds to satisfy the 2-second hold
      await tester.pump(const Duration(milliseconds: 2200));
      await gesture.up();
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify disarm success view
      expect(find.text('Drill Disarmed Successfully!'), findsOneWidget);
      expect(find.text('PROCEED TO MEMBERSHIP PLANS'), findsOneWidget);

      await tester.tap(find.text('PROCEED TO MEMBERSHIP PLANS'));
      await tester.pumpAndSettle();
      expect(drillFinished, isTrue);
    });
  });

  group('Phase 5 - Screen6Paywall Widget Tests', () {
    testWidgets('Allows selecting tiers and skipping with free tier', (tester) async {
      SubscriptionTier? chosenTier;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Screen6Paywall(
              onFinish: (tier) {
                chosenTier = tier;
              },
            ),
          ),
        ),
      );

      expect(find.text('Choose Your Protection'), findsOneWidget);
      expect(find.text('AURA Free'), findsOneWidget);
      expect(find.text('AURA Pro'), findsOneWidget);
      expect(find.text('AURA Family Circle'), findsOneWidget);

      // Tap Skip for now
      final skipBtn = find.text('Skip for now (Continue with Free Tier)');
      expect(skipBtn, findsOneWidget);
      await tester.tap(skipBtn);
      await tester.pumpAndSettle();

      expect(chosenTier, SubscriptionTier.free);
    });
  });
}
