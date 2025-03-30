import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/auth/auth_tokens.dart';
import 'package:medito/services/network/auth_api_service.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  late AuthApiService authService; // Use the real service
  late MockSecureStorageService mockSecureStorage;

  setUpAll(() {
    // REMOVE: Fallback values if they were only for HTTP mocking
    // registerFallbackValue(Uri.parse('https://test.api'));
  });

  setUp(() {
    mockSecureStorage = MockSecureStorageService();
    // Instantiate the REAL service for testing its methods
    authService = AuthApiService(
        secureStorage: mockSecureStorage,
        // Provide dummy/test values for baseUrl and apiKey if needed, or rely on defaults
        baseUrl: 'http://test.base',
        customApiKey: 'test-key');

    // Mock storage methods (as before)
    when(() => mockSecureStorage.storeRefreshToken(any()))
        .thenAnswer((_) async {});
    when(() => mockSecureStorage.clearRefreshToken()).thenAnswer((_) async {});
    when(() => mockSecureStorage.getRefreshToken())
        .thenAnswer((_) async => 'test_refresh_token');
  });

  group('AuthApiService.handleErrorResponse', () {
    // Test the specific method
    test('throws EmailExistsError when server returns EMAIL_ASSOCIATED error',
        () async {
      // Arrange
      final errorContent = jsonEncode({
        'message': 'Email exists for this account',
        'code': 'EMAIL_ASSOCIATED'
      });

      // Act & Assert: Call the public testable method directly
      expect(
        () =>
            authService.handleErrorResponse(HttpStatus.forbidden, errorContent),
        throwsA(
          isA<EmailExistsError>().having(
              (e) => e.message, 'message', 'Email exists for this account'),
        ),
      );
    });

    test('throws RateLimitException when server returns rate limit error',
        () async {
      // Arrange
      final errorContent = jsonEncode({
        'message': 'Wait 50 seconds',
        'rate_limited': true,
        'retry_after': 50
      });

      // Act & Assert: Call the public testable method directly
      expect(
        () => authService.handleErrorResponse(
            HttpStatus.tooManyRequests, errorContent),
        throwsA(
          isA<RateLimitError>()
              .having((e) => e.message, 'message', 'Wait 50 seconds')
              .having((e) => e.tryAfterSeconds, 'tryAfterSeconds', 50),
        ),
      );
    });

    test(
        'throws RefreshTokenError when server returns invalid refresh token error',
        () async {
      // Arrange
      final errorContent = jsonEncode({'message': 'Invalid refresh token'});

      // Act & Assert: Call the public testable method directly
      expect(
        () => authService.handleErrorResponse(
            HttpStatus.unauthorized, errorContent),
        throwsA(isA<RefreshTokenError>()),
      );
    });

    test('throws NotFoundError when server returns 404', () async {
      // Arrange
      final errorContent = jsonEncode({'message': 'Not found'});

      // Act & Assert: Call the public testable method directly
      expect(
        () =>
            authService.handleErrorResponse(HttpStatus.notFound, errorContent),
        throwsA(isA<NotFoundError>()),
      );
    });

    // Add tests for ServerError, UnknownError similarly
    test('throws ServerError when server returns 500', () async {
      // Arrange
      final errorContent = jsonEncode({'message': 'Server issue'});
      // Act & Assert
      expect(
        () => authService.handleErrorResponse(
            HttpStatus.internalServerError, errorContent),
        throwsA(isA<ServerError>()),
      );
    });

    test('throws UnknownError for other client errors (e.g., 400)', () async {
      // Arrange
      final errorContent = jsonEncode({'message': 'Bad request'});
      // Act & Assert
      expect(
        () => authService.handleErrorResponse(
            HttpStatus.badRequest, errorContent),
        throwsA(isA<UnknownError>()),
      );
    });
  });

  group('AuthApiService other methods', () {
    // These tests remain valid as they only mock SecureStorageService
    test('setAuthTokens stores refresh token', () async {
      final tokens = AuthTokens(
          accessToken: 'a', refreshToken: 'r', expiresIn: 1, clientId: 'c');
      await authService.setAuthTokens(tokens);
      verify(() => mockSecureStorage.storeRefreshToken('r')).called(1);
    });

    test('clearAuthTokens removes refresh token', () async {
      await authService.clearAuthTokens();
      verify(() => mockSecureStorage.clearRefreshToken()).called(1);
    });

    test('getStoredRefreshToken returns token', () async {
      when(() => mockSecureStorage.getRefreshToken())
          .thenAnswer((_) async => 'stored');
      final token = await authService.getStoredRefreshToken();
      expect(token, equals('stored'));
      verify(() => mockSecureStorage.getRefreshToken()).called(1);
    });
  });
}
