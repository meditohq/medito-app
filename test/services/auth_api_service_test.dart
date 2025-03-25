import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/auth/auth_tokens.dart';
import 'package:medito/services/network/auth_api_service.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';

// Mock dependencies
class MockSecureStorage extends Mock implements SecureStorage {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockHttpClientWrapper extends Mock implements HttpClientWrapper {}

class MockHttpClient extends Mock implements HttpClient {}

class MockHttpClientRequest extends Mock implements HttpClientRequest {}

class MockHttpClientResponse extends Mock implements HttpClientResponse {}

class MockHttpHeaders extends Mock implements HttpHeaders {}

class MockStreamSubscription extends Mock
    implements StreamSubscription<List<int>> {}

// Fake for Uri class
class FakeUri extends Fake implements Uri {}

// Custom matcher for URI
class UriMatcher extends Matcher {
  final String contains;

  UriMatcher(this.contains);

  @override
  bool matches(dynamic item, Map matchState) {
    return item is Uri && item.toString().contains(contains);
  }

  @override
  Description describe(Description description) {
    return description.add('URI contains $contains');
  }
}

// Simplified test approach - use test-only version of methods instead of full HTTP mocking
class TestableAuthApiService extends AuthApiService {
  TestableAuthApiService({
    required SecureStorageService secureStorage,
  }) : super(
          secureStorage: secureStorage,
          baseUrl: 'https://test.api',
          customApiKey: 'test-api-key',
        );

  // Override _post to avoid HTTP calls
  @override
  Future<Map<String, dynamic>> _post(String path, {dynamic body}) async {
    // For sign in
    if (path.contains('signin')) {
      final clientId = body['client_id'] as String;
      final email = body['email'] as String?;

      return {
        'access_token': 'test-access-token',
        'refresh_token': 'test-refresh-token',
        'expires_in': 3600,
        'client_id': clientId,
        'email': email,
      };
    }

    // For token refresh
    if (path.contains('refresh')) {
      return {
        'access_token': 'new-access-token',
        'expires_in': 3600,
      };
    }

    // For OTP request
    return {};
  }
}

void main() {
  late AuthApiService authService;
  late MockSecureStorageService mockSecureStorage;
  late MockHttpClientWrapper mockHttpClientWrapper;
  late MockHttpClient mockHttpClient;

  setUp(() {
    // Initialize Flutter test binding
    TestWidgetsFlutterBinding.ensureInitialized();

    mockSecureStorage = MockSecureStorageService();
    mockHttpClientWrapper = MockHttpClientWrapper();
    mockHttpClient = MockHttpClient();

    // Set up mocks
    when(() => mockHttpClientWrapper.createClient()).thenReturn(mockHttpClient);
    when(() => mockSecureStorage.storeRefreshToken(any()))
        .thenAnswer((_) async {});
    when(() => mockSecureStorage.clearRefreshToken()).thenAnswer((_) async {});

    // Create a test instance with injected dependencies
    authService = AuthApiService(
      secureStorage: mockSecureStorage,
      httpClientWrapper: mockHttpClientWrapper,
      baseUrl: 'https://test.auth.api',
      customApiKey: 'test-api-key',
    );
  });

  group('AuthApiService', () {
    test('setAuthTokens stores refresh token in secure storage', () async {
      // Setup - this test doesn't require HTTP mocking
      final tokens = AuthTokens(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        expiresIn: 900,
        clientId: 'test-client-id',
      );

      // Action
      await authService.setAuthTokens(tokens);

      // Verify
      verify(() => mockSecureStorage.storeRefreshToken('test-refresh-token'))
          .called(1);
    });

    test('clearAuthTokens removes tokens from secure storage', () async {
      // No setup needed - this test doesn't require HTTP mocking

      // Action
      await authService.clearAuthTokens();

      // Verify
      verify(() => mockSecureStorage.clearRefreshToken()).called(1);
    });

    test('getStoredRefreshToken returns token from secure storage', () async {
      // Setup
      when(() => mockSecureStorage.getRefreshToken())
          .thenAnswer((_) async => 'stored-refresh-token');

      // Action
      final token = await authService.getStoredRefreshToken();

      // Verify
      expect(token, equals('stored-refresh-token'));
      verify(() => mockSecureStorage.getRefreshToken()).called(1);
    });
  });
}
