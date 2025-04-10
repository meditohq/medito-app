import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:mockito/mockito.dart';

class MockFirebaseAnalyticsService extends Mock
    implements FirebaseAnalyticsService {}

void main() {
  group('FirebaseAnalyticsService', () {
    test('Singleton instance works correctly', () {
      // Get two instances of the service
      final instance1 = FirebaseAnalyticsService();
      final instance2 = FirebaseAnalyticsService();

      // They should be the same instance
      expect(identical(instance1, instance2), true);
    });

    // Note: We can't fully test Firebase functionality in unit tests
    // This is more to verify the structure of our implementation
  });
}
