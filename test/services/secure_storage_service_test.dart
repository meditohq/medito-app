import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/services.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  // Add Flutter test binding initialization
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set up the method channel mocking
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    channel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'read') {
        return null; // Default return for read is null
      }
      return null;
    },
  );

  late SecureStorageService secureStorage;
  late MockSecureStorage mockStorage;

  setUp(() {
    mockStorage = MockSecureStorage();
    secureStorage = SecureStorageService(storage: mockStorage);
  });

  group('SecureStorageService', () {
    const testToken = 'test-refresh-token';
    const testKey = 'medito_refresh_token';

    test('storeRefreshToken stores token with correct key', () async {
      // Setup
      when(() => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'))).thenAnswer((_) async {});

      // Action
      await secureStorage.storeRefreshToken(testToken);

      // Verify
      verifyNever(() => mockStorage.write(key: testKey, value: testToken));
    });

    test('getRefreshToken retrieves token with correct key', () async {
      // Setup
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => testToken);

      // Action
      final result = await secureStorage.getRefreshToken();

      // Verify
      expect(result, equals(testToken));
      verify(() => mockStorage.read(key: testKey)).called(1);
    });

    test('clearRefreshToken deletes token with correct key', () async {
      // Setup
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      // Action
      await secureStorage.clearRefreshToken();

      // Verify
      verify(() => mockStorage.delete(key: testKey)).called(1);
    });

    test('clearRefreshToken handles errors gracefully', () async {
      // Setup
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenThrow(Exception('Storage error'));

      // Action & Verify - should not throw
      await secureStorage.clearRefreshToken();
    });
  });
}
