// Regression cover for the native onboarding donation page's email gate.
//
// Anonymous donors have no account email. Before this gate the native page
// created the Stripe Customer with none, which meant no receipt AND no way
// into the hosted billing portal (it authenticates by emailed magic link) —
// a recurring donation the donor could not cancel. See the 15 live no-email
// subscriptions found in Stripe on 2026-07-28.
//
// The Customer is created upstream of the Stripe payment sheet, so the email
// has to be captured *before* pay is dispatched — hence a gate, not a
// post-payment prompt.
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
    show NativeDonationPage, donationEmailFieldKey;

import '../helpers/firebase_analytics_test_helper.dart';

/// Anonymous user: no account, therefore no email to fall back on.
class _AnonymousAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Returning donor whose address survives only in the auth layer (token or
/// stored email promoted into getUserEmail()), not in the paywall config.
class _KnownEmailAuthRepository implements AuthRepository {
  @override
  String? getUserEmail() => 'returning@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

PaywallConfigModel _config({String? email}) => PaywallConfigModel(
  currencyCode: 'usd',
  email: email,
  pricing: const PaymentPricing(
    oneTime: [200, 500],
    monthly: [200, 500, 1000],
    yearly: [2500],
    currency: 'usd',
    country: 'US',
    suggested: SuggestedPricing(oneTime: 200, monthly: 500, yearly: 2500),
  ),
);

void main() {
  setUp(FirebaseAnalyticsTestHelper.setupFirebaseAnalyticsMocks);

  Future<void> pump(
    WidgetTester tester, {
    String? knownEmail,
    AuthRepository? authRepository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositorySyncProvider.overrideWithValue(
            authRepository ?? _AnonymousAuthRepository(),
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
              config: _config(email: knownEmail),
              source: 'onboarding',
              onNext: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('asks anonymous donors for an email', (tester) async {
    await pump(tester);
    expect(find.text('Email address'), findsOneWidget);
    expect(
      find.text('For your receipt and to manage your donation.'),
      findsOneWidget,
    );
  });

  // The field is deliberately always visible (see _resolveKnownEmail): a known
  // donor gets it prefilled rather than hidden, so they can correct a stale
  // address instead of being silently billed against it.
  testWidgets('prefills a known config email instead of asking', (
    tester,
  ) async {
    await pump(tester, knownEmail: 'donor@example.com');

    expect(find.text('Email address'), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(donationEmailFieldKey));
    expect(field.controller!.text, 'donor@example.com');
  });

  testWidgets('blocks pay when the email is empty', (tester) async {
    await pump(tester);

    final payButton = find.widgetWithText(ElevatedButton, 'Donate');
    await tester.ensureVisible(payButton);
    await tester.pumpAndSettle();
    await tester.tap(payButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Enter your email so we can send a receipt.'),
      findsOneWidget,
    );
  });

  testWidgets('blocks pay when the email is malformed', (tester) async {
    await pump(tester);

    await tester.enterText(find.byKey(donationEmailFieldKey), 'donor@example');
    final payButton = find.widgetWithText(ElevatedButton, 'Donate');
    await tester.ensureVisible(payButton);
    await tester.pumpAndSettle();
    await tester.tap(payButton);
    await tester.pumpAndSettle();

    expect(
      find.text('That email address does not look right.'),
      findsOneWidget,
    );
  });

  testWidgets('clears the error once the donor edits the field', (
    tester,
  ) async {
    await pump(tester);

    final payButton = find.widgetWithText(ElevatedButton, 'Donate');
    await tester.ensureVisible(payButton);
    await tester.pumpAndSettle();
    await tester.tap(payButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Enter your email so we can send a receipt.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(donationEmailFieldKey),
      'donor@example.com',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Enter your email so we can send a receipt.'),
      findsNothing,
    );
  });

  testWidgets('prefills an auth-resolved email instead of asking', (
    tester,
  ) async {
    // Mirrors a returning donor: nothing in the paywall config, but the auth
    // layer resolves an address out of tokens / SharedPreferences.
    await pump(tester, authRepository: _KnownEmailAuthRepository());

    expect(find.text('Email address'), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(donationEmailFieldKey));
    expect(field.controller!.text, 'returning@example.com');
  });
}
