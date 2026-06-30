import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

typedef Callback = void Function(MethodCall call);

// See: https://github.com/firebase/flutterfire/blob/master/packages/firebase_core/firebase_core_platform_interface/lib/src/method_channel/method_channel_firebase.dart
// And: https://github.com/firebase/flutterfire/blob/master/packages/firebase_core/firebase_core/test/mock.dart

Future<T> testMethodChannelFirebase<T>({
  required Future<T> Function() future,
  Map<String, dynamic> responses = const {},
  bool emulate = true,
}) async {
  final defaultResponses = <String, dynamic>{
    'Firebase#initializeCore': [
      {
        'name': '[DEFAULT]',
        'options': {
          'apiKey': '123',
          'appId': '1:1234567890:web:321',
          'messagingSenderId': '1234567890',
          'projectId': 'test-project',
        },
        'pluginConstants': {},
      },
    ],
    'Firebase#initializeApp': {
      'name': '[DEFAULT]',
      'options': {
        'apiKey': '123',
        'appId': '1:1234567890:web:321',
        'messagingSenderId': '1234567890',
        'projectId': 'test-project',
      },
      'pluginConstants': {},
    },
  };

  final log = <MethodCall>[];
  final methodChannel = const MethodChannel('plugins.flutter.io/firebase_core');

  if (emulate) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
          log.add(methodCall);
          final response =
              responses[methodCall.method] ??
              defaultResponses[methodCall.method];
          if (response is Exception) {
            throw response;
          }
          return response;
        });
  }

  final result = await future();
  return result;
}

void setupFirebaseAuthMocks([Callback? customHandlers]) {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Ensure that Firebase.initializeApp has been called, which sets the delegate
  Firebase.delegatePackingProperty = const _TestFirebaseDelegate();
}

// Minimal delegate to satisfy the test environment
class _TestFirebaseDelegate implements FirebasePlatform {
  const _TestFirebaseDelegate();

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    throw UnimplementedError('app() has not been implemented.');
  }

  @override
  List<FirebaseAppPlatform> get apps =>
      throw UnimplementedError('apps has not been implemented.');

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    // Return a mock app that implements the platform interface
    // Using Mocktail should handle the interface verification
    return MockFirebaseAppPlatform(); // Use Mocktail mock with mixin
  }
}

// Minimal app implementing the platform interface using Mocktail and mixin
class MockFirebaseAppPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements FirebaseAppPlatform {}
