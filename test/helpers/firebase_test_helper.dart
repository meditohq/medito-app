import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper class for setting up Firebase mocks for testing
class FirebaseTestHelper {
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
