import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../constants/http/http_constants.dart';
import '../../models/stripe/payment_config_model.dart';
import '../../services/network/donation_api_service.dart';
import '../../exceptions/app_error.dart';
import '../device_and_app_info/device_and_app_info_provider.dart';

part 'payment_service_provider.g.dart';

abstract class PaymentService {
  Future<PaymentConfigModel> getPaymentConfig({
    String? currency,
    String? country,
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
}

// Riverpod providers - paymentService must be defined first
@riverpod
PaymentService paymentService(Ref ref) {
  return PaymentServiceImpl(
    ref: ref,
    donationClient: DonationApiService(),
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
