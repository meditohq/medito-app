import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_mock.dart'; // Go up one directory

class MockSecureStorage extends Mock implements SecureStorage {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() async {
  // Make main async
  // Firebase testing setup
  setupFirebaseAuthMocks(); // Should resolve now
  await Firebase.initializeApp();

  // Add Flutter test binding initialization
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set up the method channel mocking for FlutterSecureStorage
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final log = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (
        MethodCall methodCall,
      ) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'read':
            return null;
          case 'write':
          case 'delete':
            return null;
          default:
            return null;
        }
      });

  late SecureStorageService secureStorageService;
  late MockSecureStorage mockSecureStorage;

  setUp(() {
    mockSecureStorage = MockSecureStorage();

    // Inject mock SharedPreferences instance
    SharedPreferences.setMockInitialValues({});

    secureStorageService = SecureStorageService(storage: mockSecureStorage);
  });

  group('SecureStorageService', () {
    const testToken = 'test-refresh-token';
    const testKey = 'medito_refresh_token';
    const backupTestKey = 'medito_backup_refresh_token';

    test(
      'getRefreshToken retrieves from secure storage first, ignoring SharedPreferences',
      () async {
        // Setup: Both storages have a token. Secure storage should be prioritized.
        SharedPreferences.setMockInitialValues({
          backupTestKey: 'some-other-token',
        });

        // Mock secure storage to return the main test token
        when(
          () => mockSecureStorage.read(key: testKey),
        ).thenAnswer((_) async => testToken);

        final result = await secureStorageService.getRefreshToken();

        expect(result, equals(testToken));
        // Verify secure storage WAS called and its value was used.
        verify(() => mockSecureStorage.read(key: testKey)).called(1);
      },
    );

    test(
      'getRefreshToken retrieves from SharedPreferences fallback if secure storage is empty',
      () async {
        SharedPreferences.setMockInitialValues({});
        when(
          () => mockSecureStorage.read(key: testKey),
        ).thenAnswer((_) async => testToken);

        final result = await secureStorageService.getRefreshToken();

        expect(result, equals(testToken));
        verify(() => mockSecureStorage.read(key: testKey)).called(1);
      },
    );

    test('clearRefreshToken deletes from both storages', () async {
      SharedPreferences.setMockInitialValues({
        backupTestKey: 'some_encrypted_token',
      });
      when(
        () => mockSecureStorage.delete(key: testKey),
      ).thenAnswer((_) async {});

      await secureStorageService.clearRefreshToken();

      verify(() => mockSecureStorage.delete(key: testKey)).called(1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(backupTestKey), isFalse);
    });

    group('getRefreshToken fallback logic', () {
      test(
        'retrieves plain text token from SharedPreferences when secure storage is empty',
        () async {
          // Setup: Secure storage empty, SharedPreferences has plain text token
          SharedPreferences.setMockInitialValues({backupTestKey: testToken});
          when(
            () => mockSecureStorage.read(key: testKey),
          ).thenAnswer((_) async => null);

          // Action
          final result = await secureStorageService.getRefreshToken();

          // Verify
          expect(result, equals(testToken));
          verify(
            () => mockSecureStorage.read(key: testKey),
          ).called(1); // Should check secure storage first
        },
      );

      test(
        'retrieves and decrypts token from SharedPreferences for backward compatibility',
        () async {
          // Setup: Secure storage empty, SharedPreferences has encrypted token
          final tempService = SecureStorageService();
          final encryptedToken = tempService.encryptToken(testToken);
          SharedPreferences.setMockInitialValues({
            backupTestKey: encryptedToken,
          });
          when(
            () => mockSecureStorage.read(key: testKey),
          ).thenAnswer((_) async => null);

          // Action
          final result = await secureStorageService.getRefreshToken();

          // Verify
          expect(result, equals(testToken));
          verify(() => mockSecureStorage.read(key: testKey)).called(1);
        },
      );

      test(
        'returns null and clears if token from SharedPreferences is corrupted',
        () async {
          // Setup: Secure storage empty, SharedPreferences has corrupted token
          const corruptedToken = 'this-is-a-bad-token-\u0000';
          SharedPreferences.setMockInitialValues({
            backupTestKey: corruptedToken,
          });
          when(
            () => mockSecureStorage.read(key: testKey),
          ).thenAnswer((_) async => null);
          // Mock the clear operation, as it will be called on the primary storage too
          when(
            () => mockSecureStorage.delete(key: testKey),
          ).thenAnswer((_) async {});

          // Action
          final result = await secureStorageService.getRefreshToken();

          // Verify
          expect(result, isNull);
          verify(() => mockSecureStorage.read(key: testKey)).called(1);
          // Verify that the clear function was called on secure storage
          verify(() => mockSecureStorage.delete(key: testKey)).called(1);
          // Verify that the corrupted token was cleared from the backup
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.containsKey(backupTestKey), isFalse);
        },
      );
    });

    // --- New Tests for Error Handling ---

    test(
      'getRefreshToken returns null if primary storage fails and backup is empty',
      () async {
        // Setup: SharedPreferences empty, SecureStorage read throws
        SharedPreferences.setMockInitialValues({});
        final exception = PlatformException(code: 'read_failed');
        when(
          () => mockSecureStorage.read(key: any(named: 'key')),
        ).thenThrow(exception);

        // Action
        final result = await secureStorageService.getRefreshToken();

        // Assert
        expect(result, isNull);
        verify(() => mockSecureStorage.read(key: testKey)).called(1);
      },
    );

    test(
      'getRefreshToken retrieves from backup when primary storage throws an error',
      () async {
        // Setup: SharedPreferences has a valid token, SecureStorage read throws
        SharedPreferences.setMockInitialValues({backupTestKey: testToken});
        final exception = PlatformException(code: 'read_failed');
        when(
          () => mockSecureStorage.read(key: any(named: 'key')),
        ).thenThrow(exception);

        // Action
        final result = await secureStorageService.getRefreshToken(
          logFailureToFirebase: false,
        );

        // Assert
        expect(result, equals(testToken));
        verify(() => mockSecureStorage.read(key: testKey)).called(1);
      },
    );

    test(
      'getRefreshToken returns null when token not found and isLoggedIn is true',
      () async {
        // Setup: Both storages return null, isLoggedIn is true
        SharedPreferences.setMockInitialValues({
          SharedPreferenceConstants.isLoggedIn: true,
        });
        when(
          () => mockSecureStorage.read(key: testKey),
        ).thenAnswer((_) async => null);

        // Action
        final result = await secureStorageService.getRefreshToken(
          logFailureToFirebase: false,
        );

        // Verify
        expect(result, isNull);
        verify(() => mockSecureStorage.read(key: testKey)).called(1);
      },
    );

    test(
      'getRefreshToken returns null when token not found and isLoggedIn is false',
      () async {
        // Setup: Both storages return null, isLoggedIn is false
        SharedPreferences.setMockInitialValues({
          SharedPreferenceConstants.isLoggedIn: false,
        });
        when(
          () => mockSecureStorage.read(key: testKey),
        ).thenAnswer((_) async => null);

        // Action
        final result = await secureStorageService.getRefreshToken();

        // Verify
        expect(result, isNull);
        verify(() => mockSecureStorage.read(key: testKey)).called(1);
      },
    );
  });
}
