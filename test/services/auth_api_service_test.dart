import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/services/analytics/crashlytics_service.dart';
import 'package:medito/services/network/auth_api_service.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockCrashlyticsService extends Mock implements CrashlyticsService {}

void main() {
  late AuthApiService authService;
  late MockSecureStorageService mockSecureStorage;
  late MockCrashlyticsService mockCrashlyticsService;

  setUp(() {
    mockSecureStorage = MockSecureStorageService();
    mockCrashlyticsService = MockCrashlyticsService();
    authService = AuthApiService(
      secureStorage: mockSecureStorage,
      crashlyticsService: mockCrashlyticsService,
      baseUrl: 'http://test.base',
      customApiKey: 'test-key',
    );

    // Common stubs for storage
    when(
      () => mockSecureStorage.getRefreshToken(),
    ).thenAnswer((_) async => 'test_refresh_token');
    when(
      () => mockSecureStorage.storeRefreshToken(any()),
    ).thenAnswer((_) async {});
    when(() => mockSecureStorage.clearRefreshToken()).thenAnswer((_) async {});
  });

  group('AuthApiService.handleErrorResponse', () {
    test(
      'throws RefreshTokenError when server returns invalid refresh token error',
      () async {
        // Arrange
        final errorContent = jsonEncode({'message': 'Invalid refresh token'});
        when(
          () => mockCrashlyticsService.recordError(
            any(),
            any(),
            reason: any(named: 'reason'),
          ),
        ).thenAnswer((_) async {});

        // Act & Assert: Call the public testable method directly
        expect(
          () => authService.handleErrorResponse(
            HttpStatus.unauthorized,
            errorContent,
          ),
          throwsA(isA<RefreshTokenError>()),
        );
      },
    );

    test(
      'throws UnauthorizedError when server returns 401 but not invalid refresh token',
      () async {
        // Arrange
        final errorContent = jsonEncode({'message': 'Unauthorized'});

        // Act & Assert: Call the public testable method directly
        expect(
          () => authService.handleErrorResponse(
            HttpStatus.unauthorized,
            errorContent,
          ),
          throwsA(isA<UnauthorizedError>()),
        );
      },
    );

    test('throws InactiveEmailError on 422 or 406 status code', () {
      final errorContent = jsonEncode({'error': 'Inactive email'});

      expect(
        () => authService.handleErrorResponse(
          HttpStatus.unprocessableEntity,
          errorContent,
        ),
        throwsA(isA<InactiveEmailError>()),
      );

      expect(
        () => authService.handleErrorResponse(
          HttpStatus.notAcceptable,
          errorContent,
        ),
        throwsA(isA<InactiveEmailError>()),
      );
    });

    test('throws RateLimitError on 429 status code with rate_limited flag', () {
      final errorContent = jsonEncode({
        'message': 'Too many requests',
        'rate_limited': true,
        'retry_after': 60,
      });

      expect(
        () => authService.handleErrorResponse(
          HttpStatus.tooManyRequests,
          errorContent,
        ),
        throwsA(isA<RateLimitError>()),
      );
    });

    test('throws EmailExistsError on 403 with EMAIL_ASSOCIATED code', () {
      final errorContent = jsonEncode({
        'message': 'Device already associated with an email',
        'code': 'EMAIL_ASSOCIATED',
        'email': 'test@example.com',
      });

      expect(
        () =>
            authService.handleErrorResponse(HttpStatus.forbidden, errorContent),
        throwsA(isA<EmailExistsError>()),
      );
    });
  });
}
