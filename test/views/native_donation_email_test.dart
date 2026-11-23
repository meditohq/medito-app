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
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';

import 'package:medito/l10n/app_localizations.dart';

import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/models/stripe/payment_config_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart';
import 'package:medito/providers/stripe/payment_providers.dart';
import 'package:medito/utils/receipt_email.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/services/network/donation_api_service.dart';
import 'package:medito/views/donation/receipt_email_prompt.dart'
    show debugDonationEmailOutcomes, receiptEmailPromptFieldKey;
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/views/donation/native_donation_page.dart'
    show NativeDonationPage, donationEmailFieldKey, donationPayButtonKey;

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

class _SlowReceiptStore extends InMemorySharedPreferencesStore {
  _SlowReceiptStore() : super.empty();
  final release = Completer<void>();
  int writes = 0;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.endsWith(SharedPreferenceConstants.emailAddressForReceipt)) {
      writes++;
      await release.future;
    }
    return super.setValue(type, key, value);
  }
}

class _CapturePayment extends PaymentUIController {
  final amounts = <int>[];
  final emails = <String?>[];
  final methods = <PaymentMethodType>[];
  @override
  void build() {}

  @override
  Future<PaymentResult> initiateMonthlySubscription({
    required BuildContext context,
    required int amount,
    required String currency,
    required PaymentMethodType paymentMethod,
    String? paywallId,
    String? userId,
    String? userEmail,
    String? paywallSource,
    String? variantId,
    String? experimentId,
    VoidCallback? onSuccess,
    bool showSuccessFeedback = true,
    Map<String, String> campaignMetadata = const {},
  }) async {
    amounts.add(amount);
    emails.add(userEmail);
    methods.add(paymentMethod);
    return const PaymentResult.cancelled();
  }
}

/// A payment still in flight: the sheet is up and nothing has come back yet.
class _PendingPayment extends PaymentUIController {
  final release = Completer<void>();
  @override
  void build() {}

  @override
  Future<PaymentResult> initiateMonthlySubscription({
    required BuildContext context,
    required int amount,
    required String currency,
    required PaymentMethodType paymentMethod,
    String? paywallId,
    String? userId,
    String? userEmail,
    String? paywallSource,
    String? variantId,
    String? experimentId,
    VoidCallback? onSuccess,
    bool showSuccessFeedback = true,
    Map<String, String> campaignMetadata = const {},
  }) async {
    await release.future;
    return const PaymentResult.cancelled();
  }
}

/// A payment that goes through, as the real controller reports it.
class _SucceedingPayment extends PaymentUIController {
  @override
  void build() {}

  @override
  Future<PaymentResult> initiateMonthlySubscription({
    required BuildContext context,
    required int amount,
    required String currency,
    required PaymentMethodType paymentMethod,
    String? paywallId,
    String? userId,
    String? userEmail,
    String? paywallSource,
    String? variantId,
    String? experimentId,
    VoidCallback? onSuccess,
    bool showSuccessFeedback = true,
    Map<String, String> campaignMetadata = const {},
  }) async {
    onSuccess?.call();
    return PaymentResult.success(
      paymentIntentId: 'pi_1',
      amount: amount,
      currency: currency,
    );
  }
}

class _PaidState extends PaymentState {
  @override
  PaymentStateData build() => const PaymentStateData(
    paymentIntent: PaymentIntentModel(
      id: 'pi_1',
      clientSecret: 'pi_1_secret',
      status: 'succeeded',
      amount: 500,
      currency: 'usd',
    ),
  );
}

/// Donate API stand-in: answers the receipt-email check from [customerHasEmail]
/// until an address is posted.
class _ReceiptEmailApi implements IDonationApiService {
  _ReceiptEmailApi({required this.customerHasEmail, this.acceptsEmail = true});
  final bool customerHasEmail;

  /// False models a 200 that still reports no address after one is posted.
  final bool acceptsEmail;
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> postRequest(String path, {dynamic body}) async {
    expect(path, 'payment-intents/receipt-email');
    final sent = Map<String, dynamic>.from(body as Map);
    bodies.add(sent);
    return {
      'success': true,
      'data': {
        'hasEmail':
            customerHasEmail || (acceptsEmail && sent.containsKey('email')),
      },
    };
  }

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
  final emailOutcomes = <String>[];
  setUp(() {
    emailOutcomes.clear();
    debugDonationEmailOutcomes = emailOutcomes;
  });
  tearDown(() => debugDonationEmailOutcomes = null);

  Future<void> pump(
    WidgetTester tester, {
    String? knownEmail,
    AuthRepository? authRepository,
    SharedPreferences? prefs,
    PaymentUIController? payments,
    bool applePay = false,
    IDonationApiService? donateApi,
    VoidCallback? onNext,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
          if (payments != null)
            paymentUIControllerProvider.overrideWith(() => payments),
          if (donateApi != null) ...[
            donationServiceProvider.overrideWithValue(donateApi),
            paymentStateProvider.overrideWith(_PaidState.new),
          ],
          authRepositorySyncProvider.overrideWithValue(
            authRepository ?? _AnonymousAuthRepository(),
          ),
          // Card-only: keeps the Apple Pay branch out of the widget tree.
          availablePaymentMethodsProvider.overrideWith(
            (ref) async => <PaymentMethod>[
              if (applePay)
                const PaymentMethod(
                  id: 'apple_pay',
                  type: PaymentMethodType.applePay,
                  displayName: 'Apple Pay',
                  isAvailable: true,
                ),
              const PaymentMethod(
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
              onNext: onNext ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('does not ask anonymous donors for an email on the page', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(donationEmailFieldKey), findsNothing);
  });

  testWidgets(
    'repeated taps during receipt storage create one payment with the tapped amount',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = _SlowReceiptStore();
      SharedPreferencesStorePlatform.instance = store;
      final prefs = await SharedPreferences.getInstance();
      final payments = _CapturePayment();
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      await pump(
        tester,
        knownEmail: 'donor@example.invalid',
        prefs: prefs,
        payments: payments,
      );
      final pay = tester
          .widget<ElevatedButton>(find.byKey(donationPayButtonKey))
          .onPressed!;
      // Both callbacks arrive before the disabled button is rebuilt.
      pay();
      pay();
      await tester.pump();
      expect(store.writes, 1);
      expect(payments.amounts, isEmpty);
      // Even if a preset changes while preparation is pending, the request must
      // retain the amount that was displayed when Pay was pressed.
      await tester.tap(find.text('\$10'));
      await tester.pump();
      store.release.complete();
      await tester.pumpAndSettle();
      expect(payments.amounts, [500]);
    },
  );

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

  testWidgets('pays without an email: the card sheet collects it', (
    tester,
  ) async {
    final payments = _CapturePayment();
    await pump(tester, payments: payments);

    final payButton = find.byKey(donationPayButtonKey);
    await tester.ensureVisible(payButton);
    await tester.pumpAndSettle();
    await tester.tap(payButton);
    await tester.pumpAndSettle();

    expect(payments.methods, [PaymentMethodType.card]);
    expect(payments.emails, [null]);
    expect(find.byKey(donationEmailFieldKey), findsNothing);
  });

  testWidgets('blocks pay when a known email is malformed', (tester) async {
    final payments = _CapturePayment();
    await pump(tester, knownEmail: 'donor@example', payments: payments);

    final payButton = find.byKey(donationPayButtonKey);
    await tester.ensureVisible(payButton);
    await tester.pumpAndSettle();
    await tester.tap(payButton);
    await tester.pumpAndSettle();

    expect(payments.amounts, isEmpty);
    expect(
      find.text('That email address does not look right.'),
      findsOneWidget,
    );
  });

  testWidgets('clears the error once the donor edits the field', (
    tester,
  ) async {
    await pump(tester, knownEmail: 'donor@example');

    final payButton = find.byKey(donationPayButtonKey);
    await tester.ensureVisible(payButton);
    await tester.pumpAndSettle();
    await tester.tap(payButton);
    await tester.pumpAndSettle();
    expect(
      find.text('That email address does not look right.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(donationEmailFieldKey),
      'donor@example.com',
    );
    await tester.pumpAndSettle();
    expect(find.text('That email address does not look right.'), findsNothing);
  });

  testWidgets('an emptied known email is left to the sheet', (tester) async {
    final payments = _CapturePayment();
    await pump(tester, knownEmail: 'donor@example.com', payments: payments);

    await tester.enterText(find.byKey(donationEmailFieldKey), '');
    await tester.pumpAndSettle();
    // The field stays put while it is being edited.
    expect(find.byKey(donationEmailFieldKey), findsOneWidget);

    final payButton = find.byKey(donationPayButtonKey);
    await tester.ensureVisible(payButton);
    await tester.tap(payButton);
    await tester.pumpAndSettle();
    expect(payments.emails, [null]);
  });

  testWidgets('reuses the receipt email from an earlier donation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.emailAddressForReceipt: 'earlier@example.com',
    });
    final prefs = await SharedPreferences.getInstance();
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final payments = _CapturePayment();
    await pump(tester, prefs: prefs, payments: payments);

    final payButton = find.byKey(donationPayButtonKey);
    await tester.ensureVisible(payButton);
    await tester.tap(payButton);
    await tester.pumpAndSettle();
    expect(payments.emails, ['earlier@example.com']);
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

  group('where Apple Pay is offered', () {
    // Reset inside each test body: the binding checks the override is cleared
    // before tearDown callbacks run.
    Future<void> onIOS(Future<void> Function() body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    final applePayButton = find.widgetWithText(ElevatedButton, 'Pay');

    testWidgets('Apple Pay needs no email on the page', (tester) async {
      await onIOS(() async {
        final payments = _CapturePayment();
        await pump(tester, payments: payments, applePay: true);
        expect(find.byKey(donationEmailFieldKey), findsNothing);

        await tester.ensureVisible(applePayButton);
        await tester.tap(applePayButton);
        await tester.pumpAndSettle();

        // No address is sent: the Apple Pay sheet collects it instead.
        expect(payments.methods, [PaymentMethodType.applePay]);
        expect(payments.emails, [null]);
        expect(find.byKey(donationEmailFieldKey), findsNothing);
      });
    });

    testWidgets('the spinner shows on the Apple Pay button that was tapped', (
      tester,
    ) async {
      await onIOS(() async {
        final payments = _PendingPayment();
        await pump(tester, payments: payments, applePay: true);

        await tester.ensureVisible(applePayButton);
        await tester.tap(applePayButton);
        await tester.pump();

        // The card button keeps its label; it used to take the spinner.
        final cardButton = find.byKey(donationPayButtonKey);
        expect(
          find.descendant(
            of: cardButton,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: cardButton,
            matching: find.text('Donate with card'),
          ),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        payments.release.complete();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    testWidgets('card needs no email on the page either', (tester) async {
      await onIOS(() async {
        final payments = _CapturePayment();
        await pump(tester, payments: payments, applePay: true);

        await tester.ensureVisible(find.byKey(donationPayButtonKey));
        await tester.tap(find.byKey(donationPayButtonKey));
        await tester.pumpAndSettle();

        // No address is sent: the card sheet collects it instead.
        expect(payments.methods, [PaymentMethodType.card]);
        expect(payments.emails, [null]);
        expect(find.byKey(donationEmailFieldKey), findsNothing);
      });
    });

    Future<void> payWithApplePay(WidgetTester tester) async {
      await tester.ensureVisible(applePayButton);
      await tester.tap(applePayButton);
      await tester.pumpAndSettle();
    }

    testWidgets('moves on without asking when the sheet supplied the email', (
      tester,
    ) async {
      await onIOS(() async {
        final api = _ReceiptEmailApi(customerHasEmail: true);
        var advanced = 0;
        await pump(
          tester,
          payments: _SucceedingPayment(),
          applePay: true,
          donateApi: api,
          onNext: () => advanced++,
        );

        await payWithApplePay(tester);

        expect(api.bodies, [
          {'paymentIntentId': 'pi_1', 'clientSecret': 'pi_1_secret'},
        ]);
        expect(find.byKey(receiptEmailPromptFieldKey), findsNothing);
        expect(advanced, 1);
        expect(emailOutcomes, ['sheet']);
      });
    });

    testWidgets('asks afterwards when no email reached Stripe', (tester) async {
      await onIOS(() async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final api = _ReceiptEmailApi(customerHasEmail: false);
        var advanced = 0;
        await pump(
          tester,
          prefs: prefs,
          payments: _SucceedingPayment(),
          applePay: true,
          donateApi: api,
          onNext: () => advanced++,
        );

        await payWithApplePay(tester);

        expect(find.text('Where should we send your receipt?'), findsOneWidget);
        // Held on the page until the donor answers.
        expect(advanced, 0);

        // A bad address is caught before it is sent.
        await tester.enterText(find.byKey(receiptEmailPromptFieldKey), 'nope');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(api.bodies, hasLength(1));
        expect(
          find.text('That email address does not look right.'),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(receiptEmailPromptFieldKey),
          'late@example.invalid',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(api.bodies.last, {
          'paymentIntentId': 'pi_1',
          'clientSecret': 'pi_1_secret',
          'email': 'late@example.invalid',
        });
        expect(ReceiptEmail.read(prefs), 'late@example.invalid');
        expect(advanced, 1);
      });
    });

    testWidgets('does not remember an address Stripe did not take', (
      tester,
    ) async {
      await onIOS(() async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final api = _ReceiptEmailApi(
          customerHasEmail: false,
          acceptsEmail: false,
        );
        var advanced = 0;
        await pump(
          tester,
          prefs: prefs,
          payments: _SucceedingPayment(),
          applePay: true,
          donateApi: api,
          onNext: () => advanced++,
        );

        await payWithApplePay(tester);
        await tester.enterText(
          find.byKey(receiptEmailPromptFieldKey),
          'late@example.invalid',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(api.bodies, hasLength(2));
        expect(ReceiptEmail.read(prefs), isNull);
        expect(advanced, 1);
      });
    });

    testWidgets('skipping the prompt still moves on', (tester) async {
      await onIOS(() async {
        final api = _ReceiptEmailApi(customerHasEmail: false);
        var advanced = 0;
        await pump(
          tester,
          payments: _SucceedingPayment(),
          applePay: true,
          donateApi: api,
          onNext: () => advanced++,
        );

        await payWithApplePay(tester);
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        expect(api.bodies, hasLength(1));
        expect(advanced, 1);
        expect(emailOutcomes, ['prompt_skipped']);
      });
    });

    testWidgets('a known email is still sent with Apple Pay', (tester) async {
      await onIOS(() async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final payments = _CapturePayment();
        await pump(
          tester,
          knownEmail: 'donor@example.invalid',
          prefs: prefs,
          payments: payments,
          applePay: true,
        );
        expect(find.byKey(donationEmailFieldKey), findsNothing);

        await tester.ensureVisible(applePayButton);
        await tester.tap(applePayButton);
        await tester.pumpAndSettle();

        expect(payments.emails, ['donor@example.invalid']);
      });
    });
  });
}
