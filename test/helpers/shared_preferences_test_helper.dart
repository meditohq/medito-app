import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper for setting up SharedPreferences mocks in tests
class SharedPreferencesTestHelper {
  /// Setup method channel mocks for SharedPreferences
  static void setupSharedPreferencesMocks() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Setup mock for the SharedPreferences method channel
    const MethodChannel channel = MethodChannel(
      'plugins.flutter.io/shared_preferences',
    );

    // Create a mock map to hold the preferences
    final Map<String, Object> preferences = <String, Object>{};

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getAll':
              return preferences;
            case 'setBool':
              preferences[(methodCall.arguments as Map)['key']] =
                  (methodCall.arguments as Map)['value'];
              return true;
            case 'setInt':
              preferences[(methodCall.arguments as Map)['key']] =
                  (methodCall.arguments as Map)['value'];
              return true;
            case 'setDouble':
              preferences[(methodCall.arguments as Map)['key']] =
                  (methodCall.arguments as Map)['value'];
              return true;
            case 'setString':
              preferences[(methodCall.arguments as Map)['key']] =
                  (methodCall.arguments as Map)['value'];
              return true;
            case 'setStringList':
              preferences[(methodCall.arguments as Map)['key']] =
                  (methodCall.arguments as Map)['value'];
              return true;
            case 'remove':
              preferences.remove((methodCall.arguments as Map)['key']);
              return true;
            case 'clear':
              preferences.clear();
              return true;
            default:
              return null;
          }
        });
  }
}
