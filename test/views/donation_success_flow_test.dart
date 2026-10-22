import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/me/me_model.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stripe/payment_providers.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ConfirmedCardService extends CardPaymentService {
  _ConfirmedCardService(super.ref);

  @override
  Future<PaymentIntentModel> createPaymentIntent(
    PaymentIntentRequest request,
  ) async => PaymentIntentModel(
    id: 'pi_test',
    clientSecret: 'test_only',
    status: 'succeeded',
    amount: request.amount,
    currency: request.currency,
  );

  @override
  Future<PaymentResult> processPayment(PaymentIntentModel intent) async =>
      PaymentResult.success(
        paymentIntentId: intent.id,
        amount: intent.amount,
        currency: intent.currency,
      );
}

void main() {
  for (final scenario in [
    ('onboarding', 'one_time', true),
    ('end_screen', 'monthly', true),
    ('settings', 'yearly', true),
    ('announcement', 'monthly', true),
    ('webview', 'monthly', false),
  ]) {
    testWidgets(
      '${scenario.$1}: acknowledge before navigating, record gift immediately',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          SharedPreferenceConstants.userId: 'test-user',
          SharedPreferenceConstants.analyticsFirebaseEnabled: false,
          SharedPreferenceConstants.analyticsMetaEnabled: false,
        });
        final prefs = await SharedPreferences.getInstance();
        var navigated = false;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              meProvider.overrideWith(
                (ref) async => const MeModel(id: 'test-user'),
              ),
              cardPaymentServiceProvider.overrideWith(
                _ConfirmedCardService.new,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      final ui = ref.read(paymentUIControllerProvider.notifier);
                      final pay = switch (scenario.$2) {
                        'monthly' => ui.initiateMonthlySubscription,
                        'yearly' => ui.initiateYearlySubscription,
                        _ => ui.initiateOneTimePayment,
                      };
                      await pay(
                        context: context,
                        amount: 500,
                        currency: 'eur',
                        paymentMethod: PaymentMethodType.card,
                        paywallSource: scenario.$1,
                        showSuccessFeedback: scenario.$3,
                        onSuccess: () {
                          navigated = true;
                        },
                      );
                    },
                    child: const Text('Donate'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Donate'));
        await tester.pumpAndSettle();
        expect(
          prefs.getInt(SharedPreferenceConstants.lastSuccessfulDonationAtMs),
          isNotNull,
        );
        if (scenario.$3) {
          expect(navigated, isFalse);
          expect(find.text('Thank You for Your Support'), findsOneWidget);
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
        } else {
          expect(find.text('Thank You for Your Support'), findsNothing);
        }
        expect(navigated, isTrue);
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  }
}
