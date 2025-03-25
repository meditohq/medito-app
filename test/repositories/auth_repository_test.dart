import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/constants.dart' hide AuthTokens;
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/auth/auth_tokens.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/network/auth_api_service.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Mock dependencies
class MockAuthApiService extends Mock implements AuthApiService {}

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockHttpApiService extends Mock implements HttpApiService {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockUuid extends Mock implements Uuid {}

class TestableAuthRepository extends AuthRepository {
  final AuthApiService authService;
  final SecureStorageService secureStorage;
  final HttpApiService httpApiService;
  AuthTokens? tokens;
  User? _currentUser;

  TestableAuthRepository({
    required this.authService,
    required this.secureStorage,
    required this.httpApiService,
  });

  @override
  User? get currentUser => _currentUser;

  set currentUserForTest(User? value) => _currentUser = value;

  @override
  Future<void> initializeUser() async {
    // Simplified for testing
    var prefs = await SharedPreferences.getInstance();
    var clientId = prefs.getString('userId');

    if (clientId == null) {
      clientId = 'test-generated-id';
      await prefs.setString('userId', clientId);
    }

    _currentUser = User(id: clientId);
  }

  @override
  Future<String> getToken() async {
    if (tokens != null && !tokens!.isExpired) {
      return tokens!.accessToken;
    }

    var refreshToken = await secureStorage.getRefreshToken();
    if (refreshToken != null) {
      tokens = await authService.refreshToken(refreshToken);
      httpApiService.setAuthHeader(tokens!.accessToken);
      return tokens!.accessToken;
    }

    throw const UnauthorizedError();
  }

  @override
  String getUserEmail() {
    return _currentUser?.email ?? '';
  }

  @override
  Future<bool> requestOtp(String email) async {
    try {
      var prefs = await SharedPreferences.getInstance();
      var clientId = prefs.getString('userId') ?? 'test-client-id';
      await authService.requestOtp(email, clientId);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> verifyOtp(String email, String otp) async {
    try {
      var prefs = await SharedPreferences.getInstance();
      var clientId = prefs.getString('userId') ?? 'test-client-id';

      tokens = await authService.signIn(
        email: email,
        otp: otp,
        clientId: clientId,
      );

      _currentUser = User(
        id: tokens!.clientId,
        email: tokens!.email,
      );

      httpApiService.setAuthHeader(tokens!.accessToken);
      await prefs.setString('userId', tokens!.clientId);
      await prefs.setBool('isLoggedIn', true);

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> signOut() async {
    try {
      await httpApiService.signOut();
    } catch (e) {
      // Continue anyway
    }

    var prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await secureStorage.clearRefreshToken();
    httpApiService.clearAuthHeader();

    // Reset user but keep the ID
    var clientId = prefs.getString('userId');
    _currentUser = clientId != null ? User(id: clientId) : null;

    return true;
  }

  @override
  Future<bool> markAccountForDeletion() async {
    return false;
  }

  @override
  Future<bool> isAccountMarkedForDeletion() async {
    return false;
  }

  @override
  Future<void> signInAnonymously() async {
    var prefs = await SharedPreferences.getInstance();
    var clientId = prefs.getString('userId') ?? 'test-client-id';

    tokens = await authService.signIn(
      clientId: clientId,
    );

    _currentUser = User(
      id: tokens!.clientId,
    );

    httpApiService.setAuthHeader(tokens!.accessToken);
    await prefs.setString('userId', tokens!.clientId);
    await prefs.setBool('isLoggedIn', true);
  }

  @override
  void resetAuthState() {
    // No-op for tests
  }
}

void main() {
  late AuthRepository authRepository;
  late MockAuthApiService mockAuthApiService;
  late MockHttpApiService mockHttpApiService;
  late MockSecureStorageService mockSecureStorageService;
  late MockSharedPreferences mockPreferences;
  late MockUuid mockUuid;

  setUp(() {
    mockAuthApiService = MockAuthApiService();
    mockHttpApiService = MockHttpApiService();
    mockSecureStorageService = MockSecureStorageService();
    mockPreferences = MockSharedPreferences();
    mockUuid = MockUuid();

    // Create testable repo with all dependencies injected
    authRepository = AuthRepositoryImpl(
      authService: mockAuthApiService,
      httpApiService: mockHttpApiService,
      secureStorage: mockSecureStorageService,
      preferences: mockPreferences,
      uuid: mockUuid,
    );
  });

  group('AuthRepository', () {
    const clientId = 'test-client-id';

    test('signInAnonymously calls API service and stores tokens', () async {
      // Setup
      final tokens = AuthTokens(
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        expiresIn: 900,
        clientId: clientId,
      );

      when(() => mockAuthApiService.signIn(clientId: any(named: 'clientId')))
          .thenAnswer((_) async => tokens);
      when(() => mockHttpApiService.setAuthHeader(any()))
          .thenAnswer((_) async {});
      when(() => mockPreferences.getString(SharedPreferenceConstants.userId))
          .thenReturn(clientId);
      when(() => mockPreferences.setString(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockPreferences.setBool(any(), any()))
          .thenAnswer((_) async => true);

      // Action
      await authRepository.signInAnonymously();

      // Verify
      verify(() => mockAuthApiService.signIn(clientId: clientId)).called(1);
      verify(() => mockHttpApiService.setAuthHeader(tokens.accessToken))
          .called(1);
      verify(() => mockPreferences.setString(
          SharedPreferenceConstants.userId, tokens.clientId)).called(1);
      verify(() => mockPreferences.setBool(
          SharedPreferenceConstants.isLoggedIn, true)).called(1);
    });

    test('verifyOtp calls API service and stores tokens', () async {
      // Setup
      const email = 'test@example.com';
      const otp = '123456';
      final tokens = AuthTokens(
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        expiresIn: 900,
        clientId: clientId,
        email: email,
      );

      when(() => mockAuthApiService.signIn(
          email: email,
          otp: otp,
          clientId: any(named: 'clientId'))).thenAnswer((_) async => tokens);
      when(() => mockHttpApiService.setAuthHeader(any()))
          .thenAnswer((_) async {});
      when(() => mockPreferences.getString(SharedPreferenceConstants.userId))
          .thenReturn(clientId);
      when(() => mockPreferences.setString(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockPreferences.setBool(any(), any()))
          .thenAnswer((_) async => true);

      // Action
      final result = await authRepository.verifyOtp(email, otp);

      // Verify
      expect(result, isTrue);
      verify(() => mockAuthApiService.signIn(
          email: email, otp: otp, clientId: clientId)).called(1);
      verify(() => mockHttpApiService.setAuthHeader(tokens.accessToken))
          .called(1);
      verify(() => mockPreferences.setString(
          SharedPreferenceConstants.userId, tokens.clientId)).called(1);
      verify(() => mockPreferences.setBool(
          SharedPreferenceConstants.isLoggedIn, true)).called(1);
    });

    test('signOut clears tokens', () async {
      // Setup
      when(() => mockHttpApiService.signOut()).thenAnswer((_) async {});
      when(() => mockSecureStorageService.clearRefreshToken())
          .thenAnswer((_) async {});
      when(() => mockHttpApiService.clearAuthHeader()).thenAnswer((_) async {});
      when(() => mockPreferences.setBool(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockPreferences.getString(SharedPreferenceConstants.userId))
          .thenReturn(clientId);

      // Action
      final result = await authRepository.signOut();

      // Verify
      expect(result, isTrue);
      verify(() => mockHttpApiService.signOut()).called(1);
      verify(() => mockSecureStorageService.clearRefreshToken()).called(1);
      verify(() => mockHttpApiService.clearAuthHeader()).called(1);
      verify(() => mockPreferences.setBool(
          SharedPreferenceConstants.isLoggedIn, false)).called(1);
    });

    test('initiateUser creates client ID with expected format', () async {
      // Setup
      final dateStr =
          DateTime.now().toString().substring(0, 10).replaceAll('-', '');
      when(() => mockUuid.v6()).thenReturn('test-uuid-value-123');
      when(() => mockPreferences.getString(SharedPreferenceConstants.userId))
          .thenReturn(null);
      when(() => mockPreferences.setString(any(), any()))
          .thenAnswer((_) async => true);

      // Action
      await authRepository.initializeUser();

      // Verify
      final verifyPattern = verify(() => mockPreferences.setString(
          SharedPreferenceConstants.userId, captureAny()));
      final capturedId = verifyPattern.captured.first as String;
      expect(capturedId, contains(dateStr));
      expect(capturedId, contains('test'));
    });

    test('requestOtp calls API service with correct parameters', () async {
      // Setup
      const email = 'test@example.com';
      when(() => mockAuthApiService.requestOtp(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockPreferences.getString(SharedPreferenceConstants.userId))
          .thenReturn(clientId);

      // Action
      await authRepository.requestOtp(email);

      // Verify
      verify(() => mockAuthApiService.requestOtp(email, clientId)).called(1);
    });

    test('getToken refreshes token when current is expired', () async {
      // Create a testable repository for this test
      final testRepo = TestableAuthRepository(
        authService: mockAuthApiService,
        secureStorage: mockSecureStorageService,
        httpApiService: mockHttpApiService,
      );

      // Setup with expired tokens
      testRepo.tokens = AuthTokens(
        accessToken: 'old-access',
        refreshToken: 'test-refresh',
        expiresIn: 0, // Expired
        clientId: clientId,
      );

      final newTokens = AuthTokens(
        accessToken: 'new-access',
        refreshToken: 'test-refresh',
        expiresIn: 900,
        clientId: clientId,
      );

      when(() => mockSecureStorageService.getRefreshToken())
          .thenAnswer((_) async => 'test-refresh');
      when(() => mockAuthApiService.refreshToken('test-refresh'))
          .thenAnswer((_) async => newTokens);
      when(() => mockHttpApiService.setAuthHeader(any()))
          .thenAnswer((_) async {});

      // Action
      final result = await testRepo.getToken();

      // Verify
      expect(result, equals(newTokens.accessToken));
      verify(() => mockAuthApiService.refreshToken('test-refresh')).called(1);
      verify(() => mockHttpApiService.setAuthHeader(newTokens.accessToken))
          .called(1);
    });
  });
}
