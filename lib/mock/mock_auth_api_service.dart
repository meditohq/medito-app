import 'package:medito/models/auth/auth_tokens.dart';
import 'package:medito/services/network/auth_api_service.dart';
import 'package:medito/utils/logger.dart';

/// Mock auth service that returns hardcoded tokens without network calls.
/// OTP flow is a no-op — sign-in succeeds immediately.
class MockAuthApiService extends AuthApiService {
  MockAuthApiService()
    : super(
        baseUrl: 'https://mock-auth.medito.invalid/',
        customApiKey: 'mock-api-key',
      );

  @override
  Future<AuthTokens> signIn({
    String? email,
    String? otp,
    required String clientId,
  }) async {
    AppLogger.d('MOCK_AUTH', 'Sign in (mock) for clientId: $clientId');
    final tokens = AuthTokens(
      accessToken: 'mock-access-token-${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'mock-refresh-token',
      expiresIn: 3600,
      clientId: clientId,
      email: email ?? 'contributor@medito.app',
    );
    await setAuthTokens(tokens);
    return tokens;
  }

  @override
  Future<void> requestOtp(String email, String clientId) async {
    AppLogger.d('MOCK_AUTH', 'OTP request (mock no-op) for: $email');
    // No-op in mock mode
  }

  @override
  Future<AuthTokens> refreshToken(String refreshToken) async {
    AppLogger.d('MOCK_AUTH', 'Token refresh (mock)');
    final tokens = AuthTokens(
      accessToken:
          'mock-access-token-refreshed-${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'mock-refresh-token',
      expiresIn: 3600,
      clientId: 'mock-client',
    );
    await setAuthTokens(tokens);
    return tokens;
  }
}
