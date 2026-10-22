import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart';
import 'package:medito/providers/donation/supporter_appeal_experiment.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stripe/payment_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CaptureCardService extends CardPaymentService {
  _CaptureCardService(super.ref, this.requests);
  final List<PaymentIntentRequest> requests;
  @override
  Future<PaymentIntentModel> createPaymentIntent(
    PaymentIntentRequest request,
  ) async {
    requests.add(request);
    return PaymentIntentModel(
      id: 'pi_test',
      clientSecret: 'test_only',
      status: 'requires_payment_method',
      amount: request.amount,
      currency: request.currency,
    );
  }

  @override
  Future<PaymentResult> processPayment(
    PaymentIntentModel paymentIntent,
  ) async => const PaymentResult.cancelled();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final isAppealCta in [true, false]) {
    test(
      'all native payment requests preserve assignment and preceding tap (CTA=$isAppealCta)',
      () async {
        SharedPreferences.setMockInitialValues({
          SharedPreferenceConstants.utmSource: 'google',
        });
        final prefs = await SharedPreferences.getInstance();
        final experiment = SupporterAppealExperiment(prefs);
        final now = DateTime.now();
        final stats = LocalAllStats.empty().copyWith(
          audioCompleted: [
            for (final days in [60, 10, 1])
              LocalAudioCompleted(
                timestamp: now
                    .subtract(Duration(days: days))
                    .millisecondsSinceEpoch,
                id: '$days',
              ),
          ],
        );
        final seed = List.generate(
          100,
          (i) => i,
        ).firstWhere((i) => Random(i).nextInt(3) == 2);
        final a = await experiment.enroll(
          stats: stats,
          now: now,
          notificationsAllowed: true,
          random: Random(seed),
        );
        await experiment.recordNotificationTap(
          jsonDecode(experiment.notificationPayload(a!))
              as Map<String, dynamic>,
          DateTime.now(),
        );
        final requests = <PaymentIntentRequest>[];
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            cardPaymentServiceProvider.overrideWith(
              (ref) => _CaptureCardService(ref, requests),
            ),
          ],
        );
        addTearDown(container.dispose);
        final tags = isAppealCta
            ? experiment.ctaMetadata()
            : <String, String>{};
        await container
            .read(oneTimePaymentControllerProvider.notifier)
            .processOneTimePayment(
              amount: 500,
              currency: 'usd',
              paymentMethod: PaymentMethodType.card,
              userId: 'test-user',
              paywallSource: isAppealCta ? 'announcement' : 'settings',
              experimentId: 'existing_price_test',
              experimentVariant: 'B',
              campaignMetadata: tags,
            );
        await container
            .read(monthlySubscriptionControllerProvider.notifier)
            .processMonthlySubscription(
              amount: 500,
              currency: 'usd',
              paymentMethod: PaymentMethodType.card,
              userId: 'test-user',
              paywallSource: isAppealCta ? 'announcement' : 'settings',
              experimentId: 'existing_price_test',
              experimentVariant: 'B',
              campaignMetadata: tags,
            );
        await container
            .read(yearlySubscriptionControllerProvider.notifier)
            .processYearlySubscription(
              amount: 500,
              currency: 'usd',
              paymentMethod: PaymentMethodType.card,
              userId: 'test-user',
              paywallSource: isAppealCta ? 'announcement' : 'settings',
              experimentId: 'existing_price_test',
              experimentVariant: 'B',
              campaignMetadata: tags,
            );
        expect(requests, hasLength(3));
        expect(requests.map((r) => r.subscriptionInterval), [
          null,
          SubscriptionInterval.month,
          SubscriptionInterval.year,
        ]);
        for (final request in requests) {
          expect(request.metadata![SupporterAppealExperiment.name], 'C');
          expect(request.metadata!['appeal_notification_click_id'], a.id);
          expect(request.metadata!['user_id'], 'test-user');
          expect(request.metadata!['experiment_id'], 'existing_price_test');
          expect(request.metadata!['experiment_variant'], 'B');
          expect(
            request.metadata!['utm_source'],
            isAppealCta ? 'medito_app' : 'google',
          );
          if (isAppealCta) {
            expect(request.metadata!['acquisition_utm_source'], 'google');
          }
        }
        expect(prefs.getString(SharedPreferenceConstants.utmSource), 'google');
      },
    );
  }
}
