// Arm B of onboarding_native_pay: the intro CTA pushes a native page whose
// close button, like the webview's, only appears after 5 seconds; closing it
// returns to the intro, which then advances onboarding exactly once.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/stripe/payment_config_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart';
import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/views/donation/native_donation_page.dart';
import 'package:medito/views/onboarding/onboarding_donation_screen.dart';
import 'package:medito/views/onboarding/onboarding_native_donation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/firebase_analytics_test_helper.dart';

class _AnonymousAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _pricing = PaymentPricing(
  oneTime: [200, 500],
  monthly: [200, 500, 1000],
  yearly: [2500],
  currency: 'usd',
  country: 'US',
  suggested: SuggestedPricing(oneTime: 200, monthly: 500, yearly: 2500),
);

final _config = PaywallConfigModel(currencyCode: 'usd', pricing: _pricing);

List<Override> _overrides(SharedPreferences prefs, {bool noMethods = false}) =>
    [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositorySyncProvider.overrideWithValue(_AnonymousAuthRepository()),
      paywallConfigProvider.overrideWith((ref) async => _config),
      paymentConfigProvider.overrideWith(
        (ref) async => const PaymentConfigModel(
          publishableKey: 'pk_test',
          merchantIdentifier: 'merchant.test',
          merchantName: 'Medito',
          countryCode: 'US',
          currencyCode: 'usd',
          supportedNetworks: ['visa'],
          pricing: _pricing,
        ),
      ),
      availablePaymentMethodsProvider.overrideWith(
        (ref) async => noMethods
            ? const <PaymentMethod>[]
            : const <PaymentMethod>[
                PaymentMethod(
                  id: 'card',
                  type: PaymentMethodType.card,
                  displayName: 'Card',
                  isAvailable: true,
                ),
              ],
      ),
    ];

Widget _app(List<Override> overrides, Widget home) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

Finder get _close => find.byIcon(Icons.close);

bool _closeTappable(WidgetTester tester) => !tester
    .widget<IgnorePointer>(
      find.ancestor(of: _close, matching: find.byType(IgnorePointer)).first,
    )
    .ignoring;

void main() {
  setUp(FirebaseAnalyticsTestHelper.setupFirebaseAnalyticsMocks);

  testWidgets('no available native payment methods selects web checkout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      _app(
        _overrides(prefs, noMethods: true),
        Consumer(
          builder: (context, ref, child) {
            final value = ref.watch(onboardingNativeCheckoutProvider);
            return Text(
              value.hasValue && value.value == null
                  ? 'web checkout'
                  : 'preparing',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('web checkout'), findsOneWidget);
  });

  testWidgets('screen readers can close the native page immediately', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var nexts = 0;
    await tester.pumpWidget(
      _app(
        _overrides(prefs),
        Scaffold(
          body: NativeDonationPage(
            config: _config,
            source: 'onboarding',
            closeButtonDelay: const Duration(seconds: 5),
            showNotNow: false,
            onNext: () => nexts++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(_closeTappable(tester), isTrue);
    await tester.tap(_close);
    expect(nexts, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a timed-out native setup does not resume payment initialization after fallback',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final delayedConfig = Completer<PaywallConfigModel>();
      var paymentSetups = 0;
      await tester.pumpWidget(
        _app(
          [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositorySyncProvider.overrideWithValue(
              _AnonymousAuthRepository(),
            ),
            paywallConfigProvider.overrideWith((ref) => delayedConfig.future),
            paymentConfigProvider.overrideWith((ref) async {
              paymentSetups++;
              throw StateError('Native setup continued after fallback');
            }),
          ],
          Consumer(
            builder: (context, ref, child) {
              final value = ref.watch(onboardingNativeCheckoutProvider);
              return Text(value.isLoading ? 'preparing' : 'fallback');
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(find.text('fallback'), findsOneWidget);
      delayedConfig.complete(_config);
      await tester.pumpAndSettle();
      expect(paymentSetups, 0);
    },
  );

  testWidgets('close fades in after the delay; Not now is hidden', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var nexts = 0;
    await tester.pumpWidget(
      _app(
        _overrides(prefs),
        Scaffold(
          body: NativeDonationPage(
            config: _config,
            source: 'onboarding',
            closeButtonDelay: const Duration(seconds: 5),
            showNotNow: false,
            onNext: () => nexts++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Not now'), findsNothing);
    expect(_closeTappable(tester), isFalse);

    await tester.pump(const Duration(seconds: 4));
    expect(_closeTappable(tester), isFalse);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_closeTappable(tester), isTrue);

    await tester.tap(_close);
    expect(nexts, 1);
  });

  testWidgets('native arm: CTA → native page → close → advances once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.onboardingNativePayVariant: 'B',
    });
    final prefs = await SharedPreferences.getInstance();
    var advances = 0;
    await tester.pumpWidget(
      _app(
        _overrides(prefs),
        OnboardingDonationScreen(onNext: () => advances++),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.byType(NativeDonationPage), findsOneWidget);
    expect(advances, 0);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    // Top-right, where the webview has its ×.
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(tester.getCenter(_close).dx, greaterThan(screenWidth / 2));
    await tester.tap(_close);
    await tester.pumpAndSettle();

    expect(find.byType(NativeDonationPage), findsNothing);
    expect(advances, 1);
  });

  testWidgets('native arm: system back closes the page and advances once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.onboardingNativePayVariant: 'B',
    });
    final prefs = await SharedPreferences.getInstance();
    var advances = 0;
    await tester.pumpWidget(
      _app(
        _overrides(prefs),
        OnboardingDonationScreen(onNext: () => advances++),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // Back is never delayed, same as the webview route.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(NativeDonationPage), findsNothing);
    expect(advances, 1);
  });
}
