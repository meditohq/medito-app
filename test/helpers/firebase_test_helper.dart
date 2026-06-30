import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper class for setting up Firebase mocks for testing
class FirebaseTestHelper {
  /// Initialize Firebase for testing
  static Future<void> initializeFirebaseForTest() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FirebasePlatform.instance = MockFirebasePlatform();
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

class MockFirebasePlatform extends FirebasePlatform {
  MockFirebasePlatform() : super();

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseApp(name: name, options: options);
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseApp(
      name: name,
      options: const FirebaseOptions(
        apiKey: 'testApiKey',
        appId: 'testAppId',
        messagingSenderId: 'testSenderId',
        projectId: 'testProjectId',
      ),
    );
  }
}

/// Mock implementation of Firebase App
class MockFirebaseApp extends FirebaseAppPlatform {
  MockFirebaseApp({String? name, FirebaseOptions? options})
    : super(
        name ?? defaultFirebaseAppName,
        options ??
            const FirebaseOptions(
              apiKey: 'testApiKey',
              appId: 'testAppId',
              messagingSenderId: 'testSenderId',
              projectId: 'testProjectId',
            ),
      );
}
