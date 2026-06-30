import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper for setting up Firebase Analytics mocks in tests
class FirebaseAnalyticsTestHelper {
  /// Setup method channel mocks for Firebase Analytics
  static void setupFirebaseAnalyticsMocks() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Setup mock for the analytics method channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_analytics'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'Analytics#getAppInstanceId':
                return 'mock-app-instance-id';
              case 'Analytics#setConsent':
                return null;
              case 'Analytics#logEvent':
                return null;
              case 'Analytics#setUserId':
                return null;
              case 'Analytics#setUserProperty':
                return null;
              case 'Analytics#setAnalyticsCollectionEnabled':
                return null;
              case 'Analytics#resetAnalyticsData':
                return null;
              case 'Analytics#setSessionTimeoutDuration':
                return null;
              case 'Analytics#setDefaultEventParameters':
                return null;
              default:
                return null;
            }
          },
        );
  }

  /// Mock FirebaseAnalytics to return for testing
  static FirebaseAnalytics getMockFirebaseAnalytics() {
    // The mock channels are already set up, so we can return a real instance
    return FirebaseAnalytics.instance;
  }
}
