// Run with --dart-define=MOCK_MODE=true: navigation returns without a payment.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/views/onboarding/onboarding_donation_screen.dart';

import '../helpers/firebase_analytics_test_helper.dart';

void main() {
  setUp(FirebaseAnalyticsTestHelper.setupFirebaseAnalyticsMocks);

  testWidgets('returning without payment advances exactly once', (
    tester,
  ) async {
    var advances = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paywallConfigProvider.overrideWith(
            (ref) async => throw Exception('offline'),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingDonationScreen(onNext: () => advances++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byType(ElevatedButton);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(advances, 1);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(advances, 1);
    await tester.pumpWidget(const SizedBox());
  }, skip: !isMockMode);
}
