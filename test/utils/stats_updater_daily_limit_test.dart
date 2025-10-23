import 'package:flutter_test/flutter_test.dart';
import 'package:medito/providers/feature_flags_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Test implementation of FeatureFlagsNotifier
class TestFeatureFlagsNotifier extends FeatureFlagsNotifier {
  final bool isStreakFreezeEnabled;

  TestFeatureFlagsNotifier({required this.isStreakFreezeEnabled});

  @override
  FeatureFlags build() {
    return FeatureFlags(isStreakFreezeEnabled: isStreakFreezeEnabled);
  }
}

void main() {
  late StatsManager statsManager;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    statsManager = StatsManager();
  });

  tearDown(() async {
    statsManager.resetForTesting();
    await prefs.clear();
  });

  // NOTE: Streak freeze AWARDING tests have been moved to streak_freeze_awarding_test.dart
  // This provides focused unit tests for the awarding logic without complex widget setup.
  // The original tests covered:
  // - Award freeze on 7-day milestones
  // - Daily limit (max 1 per day)
  // - Award again on next day
  // - Don't award when feature disabled
  // - Don't award when max freezes reached
  // - Only award on exact 7-day multiples
  //
  // All this functionality is now covered by proper unit tests in streak_freeze_awarding_test.dart

  group('Daily Streak Freeze Limit Tests', () {
    test(
        'placeholder test - real tests moved to streak_freeze_awarding_test.dart',
        () {
      // This is a placeholder to keep the test group structure
      expect(true, true);
    });
  });
}
