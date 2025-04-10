import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper class for setting up Firebase mocks for testing
class FirebaseTestHelper {
  /// Setup Firebase Core method channel mock
  static void setupFirebaseCoreMocks() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock platform interface
    setupFirebaseCorePlatform();
  }

  /// Setup Firebase Core platform interface mock
  static void setupFirebaseCorePlatform() {
    // Register the platform interface
    final platform = MockFirebaseCorePlatform();
    FirebasePlatform.instance = platform;

    // Mock method channel calls
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/firebase_core'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'Firebase#initializeCore':
            return [
              {
                'name': '[DEFAULT]',
                'options': {
                  'apiKey': 'mock-api-key',
                  'appId': 'mock-app-id',
                  'messagingSenderId': 'mock-sender-id',
                  'projectId': 'mock-project-id',
                },
                'pluginConstants': {},
              }
            ];
          case 'Firebase#initializeApp':
            return {
              'name': '[DEFAULT]',
              'options': {
                'apiKey': 'mock-api-key',
                'appId': 'mock-app-id',
                'messagingSenderId': 'mock-sender-id',
                'projectId': 'mock-project-id',
              },
              'pluginConstants': {},
            };
          default:
            return null;
        }
      },
    );
  }

  /// Initialize Firebase for testing
  static Future<void> initializeFirebaseForTest() async {
    await Firebase.initializeApp(
      name: 'test',
      options: const FirebaseOptions(
        apiKey: 'mock-api-key',
        appId: 'mock-app-id',
        messagingSenderId: 'mock-sender-id',
        projectId: 'mock-project-id',
      ),
    );
  }
}

/// A mock implementation of the [FirebasePlatform] for testing
class MockFirebaseCorePlatform extends FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseAppPlatform();
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseAppPlatform();
  }

  @override
  List<FirebaseAppPlatform> get apps {
    return [MockFirebaseAppPlatform()];
  }
}

/// A mock implementation of the [FirebaseAppPlatform] for testing
class MockFirebaseAppPlatform extends FirebaseAppPlatform {
  MockFirebaseAppPlatform()
      : super(
            defaultFirebaseAppName,
            const FirebaseOptions(
              apiKey: 'mock-api-key',
              appId: 'mock-app-id',
              messagingSenderId: 'mock-sender-id',
              projectId: 'mock-project-id',
            ));
}
