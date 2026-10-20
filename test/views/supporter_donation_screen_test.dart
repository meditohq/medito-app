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
    return const PaymentResult.cancelled();
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
    return const PaymentResult.cancelled();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supporterPaywallConfigProvider.overrideWith((ref) async => value),
          authRepositorySyncProvider.overrideWithValue(_Auth()),
          sharedPreferencesProvider.overrideWithValue(prefs),
          paymentUIControllerProvider.overrideWith(() => payments),
          availablePaymentMethodsProvider.overrideWith(
            (ref) async => const [
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
}
