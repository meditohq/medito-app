import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:medito/constants/constants.dart' hide AuthTokens;
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/auth/auth_tokens.dart';
import 'package:medito/models/me/me_model.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/repositories/me/me_repository.dart';
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

class MockMeRepository extends Mock implements MeRepository {}

void main() {
  late AuthRepositoryImpl authRepository;
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

    // Mock getUserEmail to return null by default
    when(() => mockSecureStorageService.getUserEmail())
        .thenAnswer((_) async => null);

    authRepository = AuthRepositoryImpl(
      authService: mockAuthApiService,
      httpApiService: mockHttpApiService,
      secureStorage: mockSecureStorageService,
      preferences: mockPreferences,
      uuid: mockUuid,
    );

    // Register fallback values for mocktail
    registerFallbackValue(Uri.parse('http://example.com'));
    registerFallbackValue(<String, String>{});
  });

  group('AuthRepositoryImpl', () {
    const clientId = 'test-client-id';
    const email = 'test@example.com';
    const refreshToken = 'test-refresh-token';

    test('signInAnonymously calls API service and stores tokens on success',
        () async {
      // Setup
      final tokens = AuthTokens(
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        expiresIn: 900,
        clientId: clientId,
      );
      when(() => mockPreferences.getString(SharedPreferenceConstants.userId))
          .thenReturn(clientId);
      when(() => mockAuthApiService.signIn(clientId: clientId))
          .thenAnswer((_) async => tokens);
      when(() => mockHttpApiService.setAuthHeader(any()))
          .thenAnswer((_) async {});
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

    test('signInAnonymously throws EmailExistsError when service throws it',
        () async {
      // Setup
      when(() => mockPreferences.getString(SharedPreferenceConstants.userId))
          .thenReturn(clientId);
      when(() => mockAuthApiService.signIn(clientId: clientId))
          .thenThrow(const EmailExistsError(email: email));

      // Action & Assert
      expect(() => authRepository.signInAnonymously(),
          throwsA(isA<EmailExistsError>()));
      verify(() => mockAuthApiService.signIn(clientId: clientId)).called(1);
      verifyNever(() => mockHttpApiService.setAuthHeader(any()));
      verifyNever(() =>
          mockPreferences.setBool(SharedPreferenceConstants.isLoggedIn, any()));
    });

    test('requestOtp completes successfully when service call succeeds',
        () async {
      // Setup
      when(() => mockAuthApiService.requestOtp(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockPreferences.getString(SharedPreferenceConstants.userId))
          .thenReturn(clientId);

      // Action & Assert
      await expectLater(authRepository.requestOtp(email), completes);
      verify(() => mockAuthApiService.requestOtp(email, clientId)).called(1);
    });

    test(
        'requestOtp throws RateLimitError when service throws RateLimitException',
        () async {
      // Setup
      const retrySeconds = 59;
      const exceptionMessage = 'Please wait 59 seconds';
      final serviceException = RateLimitError(
        tryAfterSeconds: retrySeconds,
        message: exceptionMessage,
      );
      when(() => mockAuthApiService.requestOtp(email, clientId))
          .thenThrow(serviceException);
      when(() => mockPreferences.getString(SharedPreferenceConstants.userId))
          .thenReturn(clientId);

      // Action & Assert
      expect(
        () => authRepository.requestOtp(email),
        throwsA(
          isA<RateLimitError>()
              .having((e) => e.message, 'message', exceptionMessage)
              .having(
                  (e) => e.tryAfterSeconds, 'tryAfterSeconds', retrySeconds),
        ),
      );
      verify(() => mockAuthApiService.requestOtp(email, clientId)).called(1);
    });

    test('requestOtp rethrows other errors from service', () async {
      // Setup
      final otherError = Exception('Some unexpected service error');
      when(() => mockAuthApiService.requestOtp(email, clientId))
          .thenThrow(otherError);
      when(() => mockPreferences.getString(SharedPreferenceConstants.userId))
          .thenReturn(clientId);

      // Action & Assert
      expect(
          () => authRepository.requestOtp(email), throwsA(equals(otherError)));
      verify(() => mockAuthApiService.requestOtp(email, clientId)).called(1);
    });

    test('verifyOtp calls API service and stores tokens', () async {
      // Setup
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
      when(() => mockSecureStorageService.storeUserEmail(any()))
          .thenAnswer((_) async {});

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
      verify(() => mockSecureStorageService.storeUserEmail(email)).called(1);
    });

    test('signOut clears tokens', () async {
      // Setup
      when(() => mockHttpApiService.signOut()).thenAnswer((_) async {});
      when(() => mockSecureStorageService.clearRefreshToken())
          .thenAnswer((_) async {});
      when(() => mockSecureStorageService.clearUserEmail())
          .thenAnswer((_) async {});
      when(() => mockHttpApiService.clearAuthHeader()).thenAnswer((_) async {});
      when(() => mockPreferences.setBool(any(), any()))
          .thenAnswer((_) async => true);

      // Action
      final result = await authRepository.signOut();

      // Verify
      expect(result, isTrue);
      verify(() => mockHttpApiService.signOut()).called(1);
      verify(() => mockSecureStorageService.clearRefreshToken()).called(1);
      verify(() => mockSecureStorageService.clearUserEmail()).called(1);
      verify(() => mockHttpApiService.clearAuthHeader()).called(1);
      verify(() => mockPreferences.setBool(
          SharedPreferenceConstants.isLoggedIn, false)).called(1);
    });

    test('initiateUser creates client ID with expected format', () async {
      // Setup
      final dateStr = DateFormat('ddMMyyyy').format(DateTime.now());
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

    test(
        'getToken refreshes token when internal token is null but refresh token exists',
        () async {
      // Setup: Assume internal token is null (initial state or after logout)
      // No need to call setTokensForTest(null) explicitly

      final newTokens = AuthTokens(
          accessToken: 'new-access',
          refreshToken: refreshToken,
          expiresIn: 900,
          clientId: clientId);

      when(() => mockSecureStorageService.getRefreshToken())
          .thenAnswer((_) async => refreshToken);
      when(() => mockSecureStorageService.getUserEmail())
          .thenAnswer((_) async => null); // Explicitly mock here too
      when(() => mockAuthApiService.refreshToken(refreshToken))
          .thenAnswer((_) async => newTokens);
      when(() => mockHttpApiService.setAuthHeader(any()))
          .thenAnswer((_) async {});

      // Action
      final result = await authRepository.getToken();

      // Verify
      expect(result, equals(newTokens.accessToken));
      verify(() => mockSecureStorageService.getRefreshToken()).called(1);
      verify(() => mockSecureStorageService.getUserEmail()).called(1);
      verify(() => mockAuthApiService.refreshToken(refreshToken)).called(1);
      verify(() => mockHttpApiService.setAuthHeader(newTokens.accessToken))
          .called(1);
    });

    test(
        'getToken throws UnauthorizedError if no internal token and no refresh token',
        () async {
      // Setup: Assume internal token is null
      // No need to call setTokensForTest(null) explicitly
      when(() => mockSecureStorageService.getRefreshToken())
          .thenAnswer((_) async => null);

      // Action & Assert
      expect(
          () => authRepository.getToken(), throwsA(isA<UnauthorizedError>()));

      // Verify
      verify(() => mockSecureStorageService.getRefreshToken()).called(1);
      verifyNever(() => mockAuthApiService.refreshToken(any()));
    });

    test(
        'initializeUser when logged in with refresh token does not refresh immediately',
        () async {
      // Setup
      when(() => mockPreferences.getString(SharedPreferenceConstants.userId))
          .thenReturn(clientId);
      when(() => mockPreferences.getBool(SharedPreferenceConstants.isLoggedIn))
          .thenReturn(true);
      when(() => mockSecureStorageService.getRefreshToken())
          .thenAnswer((_) async => refreshToken);
      when(() => mockSecureStorageService.getUserEmail())
          .thenAnswer((_) async => email);

      // Action
      await authRepository.initializeUser();

      // Verify
      expect(authRepository.currentUser, isNotNull);
      expect(authRepository.currentUser?.id, clientId);
      expect(authRepository.currentUser?.email, email);
      verifyNever(() => mockAuthApiService.refreshToken(any()));
      verifyNever(() => mockHttpApiService.setAuthHeader(any()));
    });
  });

  group('Email Migration Tests', () {
    test('skips migration for anonymous user', () async {
      when(() => mockPreferences.getBool(SharedPreferenceConstants.isLoggedIn))
          .thenReturn(false);

      await authRepository.migrateEmailToStorage();

      verifyNever(() => mockSecureStorageService.storeUserEmail(any()));
    });

    test('migrates email from current state if available', () async {
      const email = 'test@example.com';
      final mockUser = User(id: 'test-id', email: email);
      when(() => mockPreferences.getBool(SharedPreferenceConstants.isLoggedIn))
          .thenReturn(true);
      when(() => mockSecureStorageService.getUserEmail())
          .thenAnswer((_) async => null);
      when(() => mockSecureStorageService.storeUserEmail(any()))
          .thenAnswer((_) async {});

      authRepository.setCurrentUserForTesting(mockUser);
      await authRepository.migrateEmailToStorage();

      verify(() => mockSecureStorageService.storeUserEmail(email)).called(1);
    });

    test('fetches and migrates email from /me endpoint when upgrading app',
        () async {
      const email = 'test@example.com';
      final mockUser =
          User(id: 'test-id', email: null); // No email in current state
      when(() => mockPreferences.getBool(SharedPreferenceConstants.isLoggedIn))
          .thenReturn(true);
      when(() => mockSecureStorageService.getUserEmail())
          .thenAnswer((_) async => null);
      when(() => mockSecureStorageService.storeUserEmail(any()))
          .thenAnswer((_) async {});
      when(() => mockHttpApiService.getRequest(any())).thenAnswer((_) async =>
          MeModel(id: 'test-id', email: email, hasActiveSubscription: false)
              .toJson());

      authRepository.setCurrentUserForTesting(mockUser);
      await authRepository.migrateEmailToStorage();

      verify(() => mockHttpApiService.getRequest(any())).called(1);
      verify(() => mockSecureStorageService.storeUserEmail(email)).called(1);
    });

    test('handles /me endpoint returning no email', () async {
      final mockUser = User(id: 'test-id', email: null);
      when(() => mockPreferences.getBool(SharedPreferenceConstants.isLoggedIn))
          .thenReturn(true);
      when(() => mockSecureStorageService.getUserEmail())
          .thenAnswer((_) async => null);
      when(() => mockHttpApiService.getRequest(any())).thenAnswer((_) async =>
          MeModel(id: 'test-id', email: null, hasActiveSubscription: false)
              .toJson());

      authRepository.setCurrentUserForTesting(mockUser);
      await authRepository.migrateEmailToStorage();

      verify(() => mockHttpApiService.getRequest(any())).called(1);
      verifyNever(() => mockSecureStorageService.storeUserEmail(any()));
    });

    test('handles /me endpoint error gracefully', () async {
      final mockUser = User(id: 'test-id', email: null);
      when(() => mockPreferences.getBool(SharedPreferenceConstants.isLoggedIn))
          .thenReturn(true);
      when(() => mockSecureStorageService.getUserEmail())
          .thenAnswer((_) async => null);
      when(() => mockHttpApiService.getRequest(any()))
          .thenThrow(Exception('Network error'));

      authRepository.setCurrentUserForTesting(mockUser);
      await authRepository.migrateEmailToStorage();

      verify(() => mockHttpApiService.getRequest(any())).called(1);
      verifyNever(() => mockSecureStorageService.storeUserEmail(any()));
    });

    test('does not store email if already in secure storage', () async {
      const email = 'test@example.com';
      final mockUser = User(id: 'test-id', email: null);
      when(() => mockPreferences.getBool(SharedPreferenceConstants.isLoggedIn))
          .thenReturn(true);
      when(() => mockSecureStorageService.getUserEmail())
          .thenAnswer((_) async => email);

      authRepository.setCurrentUserForTesting(mockUser);
      await authRepository.migrateEmailToStorage();

      verifyNever(() => mockSecureStorageService.storeUserEmail(any()));
    });
  });
}
