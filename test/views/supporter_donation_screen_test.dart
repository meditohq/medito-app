import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/device_info/device_and_app_info_model.dart';
import 'package:medito/models/stripe/payment_config_model.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart';
import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/views/donation/supporter_donation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/models/stripe/payment_error_model.dart';
import 'package:medito/views/donation/webview_donation_screen.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import '../helpers/fake_webview_platform.dart';
import 'dart:convert';
import 'dart:async';

class _Auth implements AuthRepository {
  @override
  User get currentUser => User(id: 'known-user', email: 'donor@example.com');
  @override
  String getUserEmail() => 'donor@example.com';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

PaywallConfigModel config({bool yearly = true}) => PaywallConfigModel(
  email: 'donor@example.com',
  currencyCode: 'eur',
  pricing: const PaymentPricing(
    monthly: [900],
    yearly: [9900],
    oneTime: [200],
    currency: 'eur',
    country: 'NL',
    suggested: SuggestedPricing(monthly: 900, yearly: 9900, oneTime: 200),
  ),
  experiment: PaywallExperiment(
    id: 'existing_ladder_test',
    variant: 'B',
    config: {
      // These raw USD numbers must never be used as localized amounts.
      'monthly': [100],
      if (yearly) 'yearly': [1200],
      'sources': {
        'announcement': {
          'monthly': [700],
          if (yearly) 'yearly': [7700],
        },
        'onboarding': {
          'monthly': [300],
        },
      },
    },
  ),
);

class _Service extends MockPaymentServiceImpl {
  Map<String, String?>? request;
  @override
  Future<PaywallConfigModel> getPaywallConfig({
    String? currency,
    String? country,
    String? userId,
    String? email,
    String? source,
  }) async {
    request = {
      'currency': currency,
      'country': country,
      'user_id': userId,
      'email': email,
      'source': source,
    };
    return config();
  }
}

class _CapturePaymentUI extends PaymentUIController {
  final requests = <Map<String, Object?>>[];
  PaymentResult result = const PaymentResult.cancelled();
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
    Map<String, String> campaignMetadata = const {},
  }) async {
    requests.add({
      'frequency': 'monthly',
      'amount': amount,
      'currency': currency,
      'source': paywallSource,
      'experiment_id': experimentId,
      'variant': variantId,
      'campaign': campaignMetadata,
    });
    return result;
  }

  @override
  Future<PaymentResult> initiateYearlySubscription({
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
    Map<String, String> campaignMetadata = const {},
  }) async {
    requests.add({
      'frequency': 'yearly',
      'amount': amount,
      'currency': currency,
      'source': paywallSource,
      'experiment_id': experimentId,
      'variant': variantId,
      'campaign': campaignMetadata,
    });
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeCheckoutWebViewPlatform web;
  setUp(() {
    web = FakeCheckoutWebViewPlatform();
    WebViewPlatform.instance = web;
  });
  test(
    'fetches announcement config with the same identity and currency',
    () async {
      final service = _Service();
      final container = ProviderContainer(
        overrides: [
          paymentServiceProvider.overrideWithValue(service),
          authRepositorySyncProvider.overrideWithValue(_Auth()),
          deviceAndAppInfoProvider.overrideWith(
            (ref) async => const DeviceAndAppInfoModel(
              model: '',
              os: '',
              platform: '',
              buildNumber: '',
              appVersion: '',
              languageCode: 'en',
              currencyName: 'EUR',
              currency: 'eur',
              country: 'NL',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(
        supporterPaywallConfigProvider.future,
      );
      expect(result.experiment!.id, 'existing_ladder_test');
      expect(service.request, {
        'currency': 'eur',
        'country': 'NL',
        'user_id': 'known-user',
        'email': 'donor@example.com',
        'source': 'announcement',
      });
    },
  );

  Future<void> pump(
    WidgetTester tester, {
    required PaywallConfigModel value,
    required _CapturePaymentUI payments,
    bool setupFailure = false,
    bool configFailure = false,
    bool noMethods = false,
    bool configTimeout = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supporterPaywallConfigProvider.overrideWith((ref) async {
            if (configFailure) throw StateError('Config unavailable');
            if (configTimeout) return Completer<PaywallConfigModel>().future;
            return value;
          }),
          paymentConfigProvider.overrideWith((ref) async {
            if (setupFailure) throw UnsupportedError('Native SDK unavailable');
            return MockPaymentServiceImpl().getPaymentConfig();
          }),
          deviceAndAppInfoProvider.overrideWith(
            (ref) async => const DeviceAndAppInfoModel(
              model: '',
              os: '',
              platform: '',
              buildNumber: '',
              appVersion: '',
              languageCode: 'en',
              currencyName: 'EUR',
              currency: 'eur',
              country: 'NL',
            ),
          ),
          authRepositorySyncProvider.overrideWithValue(_Auth()),
          sharedPreferencesProvider.overrideWithValue(prefs),
          paymentUIControllerProvider.overrideWith(() => payments),
          availablePaymentMethodsProvider.overrideWith(
            (ref) async => noMethods
                ? []
                : const [
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
          home: const SupporterDonationScreen(
            campaignMetadata: {'utm_campaign': 'support_medito_june_copy_v1'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'monthly/yearly use source-localized ladders and retain server experiment and campaign',
    (tester) async {
      final payments = _CapturePaymentUI();
      await pump(tester, value: config(), payments: payments);
      expect(find.text('One-time'), findsNothing);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      Future<void> pay() async {
        final button = find.widgetWithText(ElevatedButton, 'Donate');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await pay();
      await tester.ensureVisible(find.text('Yearly'));
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();
      await pay();
      expect(payments.requests.map((r) => r['amount']), [700, 7700]);
      expect(payments.requests.map((r) => r['frequency']), [
        'monthly',
        'yearly',
      ]);
      for (final request in payments.requests) {
        expect(request['currency'], 'eur');
        expect(request['source'], 'announcement');
        expect(request['experiment_id'], 'existing_ladder_test');
        expect(request['variant'], 'B');
        expect(request['campaign'], {
          'utm_campaign': 'support_medito_june_copy_v1',
        });
      }
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('does not add yearly when the server test excludes it', (
    tester,
  ) async {
    await pump(
      tester,
      value: config(yearly: false),
      payments: _CapturePaymentUI(),
    );
    expect(find.text('Yearly'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'config/SDK failures, disabled native and missing methods open real browser checkout',
    (tester) async {
      for (final reason in [
        'config',
        'timeout',
        'setup',
        'disabled',
        'methods',
        'empty',
      ]) {
        final payments = _CapturePaymentUI();
        var value = config();
        if (reason == 'disabled') {
          value = value.copyWith(
            experiment: value.experiment!.copyWith(
              config: {'nativePaywall': false},
            ),
          );
        }
        if (reason == 'empty') {
          value = value.copyWith(
            pricing: value.pricing.copyWith(
              monthly: [],
              yearly: [],
              oneTime: [],
            ),
            experiment: null,
          );
        }
        await pump(
          tester,
          value: value,
          payments: payments,
          configFailure: reason == 'config',
          configTimeout: reason == 'timeout',
          setupFailure: reason == 'setup',
          noMethods: reason == 'methods',
        );
        final screen = tester.widget<WebViewDonationScreen>(
          find.byType(WebViewDonationScreen),
        );
        expect(screen.useNativePaymentSheet, isFalse);
        expect(screen.showImmediateCloseButton, isTrue);
        expect(
          web.controller.loaded!.queryParameters['isInAppPaymentAvailable'],
          'false',
        );
        expect(
          web.controller.loaded!.queryParameters['source'],
          'announcement',
        );
        expect(
          web.controller.loaded!.queryParameters['utm_campaign'],
          'support_medito_june_copy_v1',
        );
        expect(payments.requests, isEmpty);
        // A stale/erroneous native request cannot re-enter the failed SDK.
        web.controller.channel!.onMessageReceived(
          const JavaScriptMessage(
            message: '{"type":"paywall_payment_request","amount":700}',
          ),
        );
        await tester.pumpAndSettle();
        expect(payments.requests, isEmpty);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'native SDK availability failure falls back; cancellation and declines stay native',
    (tester) async {
      for (final type in [
        null,
        PaymentErrorType.cardDeclined,
        PaymentErrorType.paymentMethodNotSupported,
      ]) {
        final payments = _CapturePaymentUI();
        if (type != null) {
          payments.result = PaymentResult.failure(
            errorMessage: 'Test error',
            error: PaymentError(
              type: type,
              message: 'Test',
              userFriendlyMessage: 'Test',
            ),
          );
        }
        await pump(tester, value: config(), payments: payments);
        final button = find.widgetWithText(ElevatedButton, 'Donate');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          find.byType(WebViewDonationScreen),
          type == PaymentErrorType.paymentMethodNotSupported
              ? findsOneWidget
              : findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'only a succeeded browser payment on the checkout origin suppresses further asks',
    (tester) async {
      await pump(
        tester,
        value: config(),
        payments: _CapturePaymentUI(),
        setupFailure: true,
      );
      final prefs = await SharedPreferences.getInstance();
      void send(String status) => web.controller.channel!.onMessageReceived(
        JavaScriptMessage(
          message: jsonEncode({
            'type': 'web_payment_succeeded',
            'status': status,
            'payment_intent_id': 'pi_test',
            'frequency': 'yearly',
          }),
        ),
      );
      send('processing');
      await tester.pumpAndSettle();
      expect(
        prefs.containsKey(SharedPreferenceConstants.lastSuccessfulDonationAtMs),
        isFalse,
      );
      final loaded = web.controller.loaded;
      web.controller.loaded = Uri.parse('https://untrusted.example/paywall');
      send('succeeded');
      await tester.pumpAndSettle();
      expect(
        prefs.containsKey(SharedPreferenceConstants.lastSuccessfulDonationAtMs),
        isFalse,
      );
      web.controller.loaded = loaded;
      send('succeeded');
      await tester.pumpAndSettle();
      expect(
        prefs.containsKey(SharedPreferenceConstants.lastSuccessfulDonationAtMs),
        isTrue,
      );
      expect(
        prefs.getString(
          SharedPreferenceConstants.lastSuccessfulDonationFrequency,
        ),
        'yearly',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
