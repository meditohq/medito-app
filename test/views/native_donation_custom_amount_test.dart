// Regression cover for the custom-amount field's live amount echo.
//
// The 2607.20.x native page charged raw USD cents as the local currency, so
// variant-B donors were billed amounts that bore no relation to what the page
// showed. The echo exists so the resolved amount is visible on the page itself
// rather than first appearing in Apple/Google Pay's confirmation sheet.
//
// The axis that actually broke was minor-unit handling, so both a 2-decimal
// (USD) and a zero-decimal (JPY) currency are covered: typing the same digits
// must resolve to a different minor amount per currency.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medito/l10n/app_localizations.dart';

import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/models/stripe/payment_config_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/views/donation/native_donation_page.dart'
    show NativeDonationPage, customAmountFieldKey;

import '../helpers/firebase_analytics_test_helper.dart';

class _AnonymousAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Ladders are in minor units, so the same nominal tiers differ per currency:
/// 200 is $2.00 but ¥200.
PaywallConfigModel _config({
  required String currency,
  required List<int> monthly,
}) => PaywallConfigModel(
  currencyCode: currency,
  pricing: PaymentPricing(
    oneTime: monthly,
    monthly: monthly,
    yearly: monthly,
    currency: currency,
    country: currency == 'jpy' ? 'JP' : 'US',
    suggested: SuggestedPricing(
      oneTime: monthly.first,
      monthly: monthly.first,
      yearly: monthly.first,
    ),
  ),
);

void main() {
  setUp(FirebaseAnalyticsTestHelper.setupFirebaseAnalyticsMocks);

  Future<void> pump(WidgetTester tester, PaywallConfigModel config) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositorySyncProvider.overrideWithValue(
            _AnonymousAuthRepository(),
          ),
          // Card-only: keeps the Apple Pay branch out of the widget tree.
          availablePaymentMethodsProvider.overrideWith(
            (ref) async => const <PaymentMethod>[
              PaymentMethod(
                id: 'card',
                type: PaymentMethodType.card,
                displayName: 'Card',
                isAvailable: true,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NativeDonationPage(
              config: config,
              source: 'onboarding',
              onNext: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String digits) async {
    await tester.enterText(find.byKey(customAmountFieldKey), digits);
    await tester.pumpAndSettle();
  }

  testWidgets('echoes a 2-decimal currency in major units', (tester) async {
    await pump(tester, _config(currency: 'usd', monthly: [200, 500, 1000]));

    await type(tester, '25');

    // 25 major units -> 2500 minor. Not "$2,500", which is what reading the
    // typed digits as cents would have produced.
    expect(find.text('= \$25'), findsOneWidget);
  });

  testWidgets('echoes a zero-decimal currency without dividing by 100', (
    tester,
  ) async {
    await pump(tester, _config(currency: 'jpy', monthly: [300, 500, 1000]));

    await type(tester, '1000');

    // JPY has no minor unit, so 1000 typed is ¥1,000 — not ¥10.
    expect(find.text('= ¥1,000'), findsOneWidget);
  });

  testWidgets('shows no echo below the minimum', (tester) async {
    await pump(tester, _config(currency: 'usd', monthly: [200, 500, 1000]));

    // $1 is under the $2 floor: the validation error owns the field instead.
    await type(tester, '1');

    expect(find.textContaining('= '), findsNothing);
    expect(find.text('Minimum amount is \$2'), findsOneWidget);
  });

  testWidgets('drops the echo when the field is cleared', (tester) async {
    await pump(tester, _config(currency: 'usd', monthly: [200, 500, 1000]));

    await type(tester, '25');
    expect(find.text('= \$25'), findsOneWidget);

    await type(tester, '');
    expect(find.text('= \$25'), findsNothing);
  });
}
