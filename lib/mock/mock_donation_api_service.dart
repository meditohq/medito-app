import 'package:medito/mock/mock_data.dart';
import 'package:medito/services/network/donation_api_service.dart';
import 'package:medito/utils/logger.dart';

/// Mock donation API that returns hardcoded data without network calls.
class MockDonationApiService implements IDonationApiService {
  static MockDonationApiService? _instance;

  factory MockDonationApiService() {
    _instance ??= MockDonationApiService._();
    return _instance!;
  }

  MockDonationApiService._();

  @override
  Future<Map<String, dynamic>> getRequest(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    AppLogger.d('MOCK_DONATION', 'GET $path');
    return _matchResponse(path);
  }

  @override
  Future<Map<String, dynamic>> postRequest(String path, {dynamic body}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    AppLogger.d('MOCK_DONATION', 'POST $path');
    return _matchResponse(path);
  }

  Map<String, dynamic> _matchResponse(String path) {
    if (path.startsWith('donations')) {
      return mockDonation.toJson();
    }
    if (path == 'config') {
      return {
        'data': {
          'publishableKey': 'pk_test_mock',
          'merchantId': 'merchant.com.medito.mock',
        },
      };
    }
    if (path.startsWith('payment-intents')) {
      return {
        'data': {
          'id': 'pi_mock_001',
          'clientSecret': 'pi_mock_secret',
          'status': 'requires_payment_method',
          'amount': 500,
          'currency': 'usd',
        },
      };
    }
    AppLogger.w('MOCK_DONATION', 'No mock data for: $path');
    return {};
  }
}
