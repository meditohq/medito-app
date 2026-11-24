// Stripe cannot tell which build took a payment unless the app says so, and
// experiment readouts need to split the money side by release and platform.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart';
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
  final realLoader = paymentAppVersionLoader;
  setUp(debugResetPaymentAppMetadata);
  tearDown(() {
    debugResetPaymentAppMetadata();
    paymentAppVersionLoader = realLoader;
    debugDefaultTargetPlatformOverride = null;
  });

  Future<List<PaymentIntentRequest>> pay() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
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
    // The version is read when a donation surface first appears, not on the
    // pay path.
    warmPaymentAppMetadata();
    await Future<void>.delayed(Duration.zero);
    await container
        .read(oneTimePaymentControllerProvider.notifier)
        .processOneTimePayment(
          amount: 500,
          currency: 'usd',
          paymentMethod: PaymentMethodType.card,
        );
    await container
        .read(monthlySubscriptionControllerProvider.notifier)
        .processMonthlySubscription(
          amount: 500,
          currency: 'usd',
          paymentMethod: PaymentMethodType.card,
        );
    await container
        .read(yearlySubscriptionControllerProvider.notifier)
        .processYearlySubscription(
          amount: 500,
          currency: 'usd',
          paymentMethod: PaymentMethodType.card,
        );
    return requests;
  }

  test('every payment request carries the app version and platform', () async {
    paymentAppVersionLoader = () async => '2611.23.0';
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final requests = await pay();

    expect(requests, hasLength(3));
    for (final request in requests) {
      expect(request.metadata!['app_version'], '2611.23.0');
      expect(request.metadata!['platform'], 'ios');
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test('an unreadable version still sends the platform', () async {
    paymentAppVersionLoader = () async => throw StateError('no plugin');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final requests = await pay();

    expect(requests, hasLength(3));
    for (final request in requests) {
      expect(request.metadata!.containsKey('app_version'), isFalse);
      expect(request.metadata!['platform'], 'android');
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
