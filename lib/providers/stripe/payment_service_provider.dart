import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../constants/http/http_constants.dart';
import '../../constants/strings/analytics_event_constants.dart';
import '../../utils/logger.dart';
import '../../models/stripe/payment_config_model.dart';
import '../../models/stripe/paywall_config_model.dart';
import '../../repositories/auth/auth_repository.dart';
import '../../services/network/donation_api_service.dart';
import '../../exceptions/app_error.dart';
import '../device_and_app_info/device_and_app_info_provider.dart';
import 'payment_providers.dart';

part 'payment_service_provider.g.dart';

abstract class PaymentService {
  Future<PaymentConfigModel> getPaymentConfig({
    String? currency,
    String? country,
  });

  Future<PaywallConfigModel> getPaywallConfig({
    String? currency,
    String? country,
    String? userId,
    String? email,
    String? source,
  });
}

class PaymentServiceImpl implements PaymentService {
  final Ref ref;
  final IDonationApiService donationClient;

  PaymentServiceImpl({required this.ref, required this.donationClient});

  @override
  Future<PaymentConfigModel> getPaymentConfig({
    String? currency,
    String? country,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (currency != null) {
        queryParams['currency'] = currency;
      }
      if (country != null) {
        queryParams['country'] = country;
      }

      final response = await donationClient.getRequest(
        HTTPConstants.paymentConfig,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );
      final data = response['data'];
      if (data == null) {
        throw const ServerError();
      }
      final config = PaymentConfigModel.fromJson(data as Map<String, dynamic>);

      AppLogger.d('PAYMENT', 'Stripe publishableKey: ${config.publishableKey}');

      Stripe.publishableKey = config.publishableKey;
      Stripe.merchantIdentifier = config.merchantIdentifier;
      await Stripe.instance.applySettings();

      return config;
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }

  @override
  Future<PaywallConfigModel> getPaywallConfig({
    String? currency,
    String? country,
    String? userId,
    String? email,
    String? source,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'currency': ?currency,
        'country': ?country,
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        if (email != null && email.isNotEmpty) 'email': email,
        if (source != null && source.isNotEmpty) 'source': source,
      };

      final response = await donationClient.getRequest(
        HTTPConstants.paywall,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );
      final data = response['data'];
      if (data == null) {
        throw const ServerError();
      }

      return PaywallConfigModel.fromJson(data as Map<String, dynamic>);
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }
}

/// Mock implementation of [PaymentService] that returns hardcoded config
/// without touching any Stripe SDK APIs.
class MockPaymentServiceImpl implements PaymentService {
  @override
  Future<PaymentConfigModel> getPaymentConfig({
    String? currency,
    String? country,
  }) async {
    AppLogger.d('PAYMENT', 'Mock mode: returning hardcoded payment config');
    final resolvedCurrency = currency ?? 'USD';
    final resolvedCountry = country ?? 'US';
    return PaymentConfigModel(
      publishableKey: 'pk_test_mock',
      merchantIdentifier: 'merchant.com.medito.mock',
      merchantName: 'Medito',
      countryCode: resolvedCountry,
      currencyCode: resolvedCurrency,
      supportedNetworks: const ['visa', 'mastercard', 'amex'],
      pricing: PaymentPricing(
        oneTime: const [500, 1000, 2000, 5000],
        monthly: const [500, 1000, 2000],
        yearly: const [5000, 10000, 20000],
        currency: resolvedCurrency,
        country: resolvedCountry,
        suggested: const SuggestedPricing(
          oneTime: 1000,
          monthly: 1000,
          yearly: 10000,
        ),
      ),
    );
  }

  @override
  Future<PaywallConfigModel> getPaywallConfig({
    String? currency,
    String? country,
    String? userId,
    String? email,
    String? source,
  }) async {
    AppLogger.d('PAYMENT', 'Mock mode: returning hardcoded paywall config');
    final resolvedCurrency = currency ?? 'USD';
    final resolvedCountry = country ?? 'US';
    return PaywallConfigModel(
      publishableKey: 'pk_test_mock',
      merchantIdentifier: 'merchant.com.medito.mock',
      merchantName: 'Medito',
      countryCode: resolvedCountry,
      currencyCode: resolvedCurrency,
      supportedNetworks: const ['visa', 'mastercard', 'amex'],
      pricing: PaymentPricing(
        oneTime: const [500, 1000, 2000, 5000],
        monthly: const [500, 1000, 2000],
        yearly: const [5000, 10000, 20000],
        currency: resolvedCurrency,
        country: resolvedCountry,
        suggested: const SuggestedPricing(
          oneTime: 1000,
          monthly: 1000,
          yearly: 10000,
        ),
      ),
      email: email,
      experiment: const PaywallExperiment(
        id: 'mock_native_paywall',
        variant: 'B',
        config: {'nativePaywall': true},
      ),
    );
  }
}

// Riverpod providers - paymentService must be defined first
@Riverpod(keepAlive: true)
PaymentService paymentService(Ref ref) {
  return PaymentServiceImpl(
    ref: ref,
    donationClient: ref.read(donationServiceProvider),
  );
}

@Riverpod(keepAlive: true)
Future<PaymentConfigModel> paymentConfig(Ref ref) {
  final service = ref.watch(paymentServiceProvider);
  final deviceInfo = ref.watch(deviceAndAppInfoProvider).value;

  return service.getPaymentConfig(
    currency: deviceInfo?.currency,
    country: deviceInfo?.country,
  );
}

/// Resolved paywall config (pricing + experiment assignment) for the
/// onboarding donation step — same endpoint the paywall webview's JS calls,
/// with the same identity/source params the webview URL carries today.
@Riverpod(keepAlive: true)
Future<PaywallConfigModel> paywallConfig(Ref ref) {
  final service = ref.watch(paymentServiceProvider);
  final deviceInfo = ref.watch(deviceAndAppInfoProvider).value;

  // Same identity params the webview screen passes today. Anonymous sign-in
  // may still be in flight — treat the user as unknown rather than failing.
  String? userId;
  String? email;
  try {
    final currentUser = ref.read(authRepositorySyncProvider).currentUser;
    userId = currentUser?.id;
    email = currentUser?.email;
  } catch (e) {
    AppLogger.w('PAYMENT', 'Paywall config: auth not ready ($e)');
  }

  return service.getPaywallConfig(
    currency: deviceInfo?.currency,
    country: deviceInfo?.country,
    userId: userId,
    email: email,
    source: AnalyticsEventConstants.paywallSourceOnboarding,
  );
}
