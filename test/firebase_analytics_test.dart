import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';

import 'helpers/firebase_test_helper.dart';
import 'helpers/firebase_analytics_test_helper.dart';
import 'helpers/shared_preferences_test_helper.dart';

void main() {
  // Set up mocks for all required services
  setUpAll(() async {
    // Setup Firebase Core
    FirebaseTestHelper.setupFirebaseCoreMocks();
    await FirebaseTestHelper.initializeFirebaseForTest();

    // Setup Firebase Analytics
    FirebaseAnalyticsTestHelper.setupFirebaseAnalyticsMocks();

    // Setup SharedPreferences
    SharedPreferencesTestHelper.setupSharedPreferencesMocks();
  });

  group('FirebaseAnalyticsService', () {
    test('Singleton instance works correctly', () {
      // Get two instances of the service
      final instance1 = FirebaseAnalyticsService();
      final instance2 = FirebaseAnalyticsService();

      // They should be the same instance (singleton pattern)
      expect(identical(instance1, instance2), true);
    });

    test('Analytics service can be initialized', () async {
      final analytics = FirebaseAnalyticsService();

      // This should not throw any exceptions
      await analytics.initialize(requestAttPermissionImmediately: false);

      // Test passed if no exceptions were thrown
      expect(true, true);
    });

    test('Analytics service can log events', () async {
      final analytics = FirebaseAnalyticsService();

      // Initialize the service
      await analytics.initialize(requestAttPermissionImmediately: false);

      // This should not throw any exceptions
      await analytics.logEvent(name: 'test_event');

      // Test passed if no exceptions were thrown
      expect(true, true);
    });

    test('Analytics service can set consent', () async {
      final analytics = FirebaseAnalyticsService();

      // Initialize the service first
      await analytics.initialize(requestAttPermissionImmediately: false);

      // This should not throw any exceptions
      await analytics.setConsent(
        analyticsStorageConsentGranted: true,
        adStorageConsentGranted: true,
        adUserDataConsentGranted: true,
        adPersonalizationSignalsConsentGranted: true,
      );

      // Test passed if no exceptions were thrown
      expect(true, true);
    });
  });
}
