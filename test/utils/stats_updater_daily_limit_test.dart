import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/feature_flags_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/stats_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/utils/stats_updater.dart';
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

  group('Daily Streak Freeze Limit Tests', () {
    testWidgets(
        'should award freeze on first 7-day milestone completion of the day',
        (WidgetTester tester) async {
      // Set today as March 7, 2025
      final testDate = DateTime(2025, 3, 7);

      // Create test stats reaching 7-day milestone
      final initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          // 6 previous days
          LocalAudioCompleted(
              id: '1', timestamp: DateTime(2025, 3, 1).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '2', timestamp: DateTime(2025, 3, 2).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '3', timestamp: DateTime(2025, 3, 3).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '4', timestamp: DateTime(2025, 3, 4).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '5', timestamp: DateTime(2025, 3, 5).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '6', timestamp: DateTime(2025, 3, 6).millisecondsSinceEpoch),
        ],
        streakCurrent: 6,
        streakLongest: 10,
        totalTracksCompleted: 6,
        totalTimeListened: 360,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 0,
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      // Initialize stats manager with test data
      var testStatsService = StatsService(
        httpApiService: HttpApiService(),
        prefs: prefs,
      );
      statsManager.setStatsServiceForTesting(testStatsService);
      await statsManager.initializeForTesting(statsService: testStatsService);
      statsManager.setStatsForTesting(initialStats);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagsProvider.overrideWith(
                () => TestFeatureFlagsNotifier(isStreakFreezeEnabled: true)),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      // Simulate completing 7th day meditation
                      final payload = {
                        TypeConstants.trackIdKey: 'track-7',
                        TypeConstants.timestampIdKey:
                            testDate.millisecondsSinceEpoch,
                        TypeConstants.durationIdKey: 60000, // 1 minute
                      };
                      await handleStats(payload, ref: ref);
                    },
                    child: const Text('Complete Session'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to complete session (reaching 7-day milestone)
      await tester.tap(find.text('Complete Session'));
      await tester.pumpAndSettle();

      // Verify freeze was awarded
      final updatedStats = await statsManager.localAllStats;
      expect(updatedStats.streakFreezes, 1,
          reason: 'Should have 1 freeze after reaching 7-day milestone');
      expect(updatedStats.streakCurrent, 7, reason: 'Should have 7-day streak');

      // Verify SharedPreferences tracking
      final lastAwardDate = prefs.getString('last_streak_freeze_award_date');
      final expectedDate = testDate.toIso8601String().substring(0, 10);
      expect(lastAwardDate, expectedDate,
          reason: 'Should track award date in SharedPreferences');
    });

    testWidgets(
        'should NOT award second freeze on same day for multiple sessions',
        (WidgetTester tester) async {
      // Set today as March 7, 2025
      final testDate = DateTime(2025, 3, 7);

      // Pre-populate SharedPreferences with today's award date
      final today = testDate.toIso8601String().substring(0, 10);
      await prefs.setString('last_streak_freeze_award_date', today);

      // Create test stats at 7-day milestone with 1 freeze already
      final initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          // 7 days including today
          LocalAudioCompleted(
              id: '1', timestamp: DateTime(2025, 3, 1).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '2', timestamp: DateTime(2025, 3, 2).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '3', timestamp: DateTime(2025, 3, 3).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '4', timestamp: DateTime(2025, 3, 4).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '5', timestamp: DateTime(2025, 3, 5).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '6', timestamp: DateTime(2025, 3, 6).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '7', timestamp: testDate.millisecondsSinceEpoch),
        ],
        streakCurrent: 7,
        streakLongest: 10,
        totalTracksCompleted: 7,
        totalTimeListened: 420,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 1, // Already has 1 freeze from earlier today
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      // Initialize stats manager with test data
      var testStatsService = StatsService(
        httpApiService: HttpApiService(),
        prefs: prefs,
      );
      statsManager.setStatsServiceForTesting(testStatsService);
      await statsManager.initializeForTesting(statsService: testStatsService);
      statsManager.setStatsForTesting(initialStats);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagsProvider.overrideWith(
                () => TestFeatureFlagsNotifier(isStreakFreezeEnabled: true)),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      // Simulate completing SECOND session on same day
                      final payload = {
                        TypeConstants.trackIdKey: 'track-7-second',
                        TypeConstants.timestampIdKey: testDate
                            .add(const Duration(hours: 2))
                            .millisecondsSinceEpoch,
                        TypeConstants.durationIdKey: 60000, // 1 minute
                      };
                      await handleStats(payload, ref: ref);
                    },
                    child: const Text('Complete Second Session'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to complete second session on same day
      await tester.tap(find.text('Complete Second Session'));
      await tester.pumpAndSettle();

      // Verify NO additional freeze was awarded
      final updatedStats = await statsManager.localAllStats;
      expect(updatedStats.streakFreezes, 1,
          reason: 'Should still have only 1 freeze (no additional award)');
      expect(updatedStats.streakCurrent, 7,
          reason: 'Should maintain 7-day streak');
    });

    testWidgets('should award freeze again on next day',
        (WidgetTester tester) async {
      // Set yesterday as award date
      final yesterday = DateTime(2025, 3, 6);
      final today = DateTime(2025, 3, 7);
      final yesterdayString = yesterday.toIso8601String().substring(0, 10);
      await prefs.setString('last_streak_freeze_award_date', yesterdayString);

      // Create test stats at 14-day milestone (should get another freeze)
      final initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          // 13 previous days
          ...List.generate(
              13,
              (i) => LocalAudioCompleted(
                    id: 'track-${i + 1}',
                    timestamp: DateTime(2025, 2, 22 + i).millisecondsSinceEpoch,
                  )),
        ],
        streakCurrent: 13,
        streakLongest: 15,
        totalTracksCompleted: 13,
        totalTimeListened: 780,
        updated: today.millisecondsSinceEpoch,
        streakFreezes: 1, // Has 1 freeze from previous milestone
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      // Initialize stats manager with test data
      var testStatsService = StatsService(
        httpApiService: HttpApiService(),
        prefs: prefs,
      );
      statsManager.setStatsServiceForTesting(testStatsService);
      await statsManager.initializeForTesting(statsService: testStatsService);
      statsManager.setStatsForTesting(initialStats);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagsProvider.overrideWith(
                () => TestFeatureFlagsNotifier(isStreakFreezeEnabled: true)),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      // Simulate completing 14th day meditation
                      final payload = {
                        TypeConstants.trackIdKey: 'track-14',
                        TypeConstants.timestampIdKey:
                            today.millisecondsSinceEpoch,
                        TypeConstants.durationIdKey: 60000, // 1 minute
                      };
                      await handleStats(payload, ref: ref);
                    },
                    child: const Text('Complete 14th Day'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to complete 14th day session
      await tester.tap(find.text('Complete 14th Day'));
      await tester.pumpAndSettle();

      // Verify new freeze was awarded (different day)
      final updatedStats = await statsManager.localAllStats;
      expect(updatedStats.streakFreezes, 2,
          reason: 'Should have 2 freezes after 14-day milestone');
      expect(updatedStats.streakCurrent, 14,
          reason: 'Should have 14-day streak');

      // Verify SharedPreferences updated to today
      final lastAwardDate = prefs.getString('last_streak_freeze_award_date');
      final expectedDate = today.toIso8601String().substring(0, 10);
      expect(lastAwardDate, expectedDate,
          reason: 'Should update award date to today');
    });

    testWidgets('should NOT award freeze when feature is disabled',
        (WidgetTester tester) async {
      // Set today as March 7, 2025
      final testDate = DateTime(2025, 3, 7);

      // Create test stats reaching 7-day milestone
      final initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          // 6 previous days
          LocalAudioCompleted(
              id: '1', timestamp: DateTime(2025, 3, 1).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '2', timestamp: DateTime(2025, 3, 2).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '3', timestamp: DateTime(2025, 3, 3).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '4', timestamp: DateTime(2025, 3, 4).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '5', timestamp: DateTime(2025, 3, 5).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '6', timestamp: DateTime(2025, 3, 6).millisecondsSinceEpoch),
        ],
        streakCurrent: 6,
        streakLongest: 10,
        totalTracksCompleted: 6,
        totalTimeListened: 360,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 0,
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      // Initialize stats manager with test data
      var testStatsService = StatsService(
        httpApiService: HttpApiService(),
        prefs: prefs,
      );
      statsManager.setStatsServiceForTesting(testStatsService);
      await statsManager.initializeForTesting(statsService: testStatsService);
      statsManager.setStatsForTesting(initialStats);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // FEATURE DISABLED
            featureFlagsProvider.overrideWith(
                () => TestFeatureFlagsNotifier(isStreakFreezeEnabled: false)),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      // Simulate completing 7th day meditation
                      final payload = {
                        TypeConstants.trackIdKey: 'track-7',
                        TypeConstants.timestampIdKey:
                            testDate.millisecondsSinceEpoch,
                        TypeConstants.durationIdKey: 60000, // 1 minute
                      };
                      await handleStats(payload, ref: ref);
                    },
                    child: const Text('Complete Session'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to complete session (reaching 7-day milestone)
      await tester.tap(find.text('Complete Session'));
      await tester.pumpAndSettle();

      // Verify NO freeze was awarded (feature disabled)
      final updatedStats = await statsManager.localAllStats;
      expect(updatedStats.streakFreezes, 0,
          reason: 'Should not award freeze when feature is disabled');
      expect(updatedStats.streakCurrent, 7,
          reason: 'Should still update streak');

      // Verify no SharedPreferences tracking when disabled
      final lastAwardDate = prefs.getString('last_streak_freeze_award_date');
      expect(lastAwardDate, isNull,
          reason: 'Should not track award date when feature is disabled');
    });

    testWidgets('should NOT award freeze when max freezes reached',
        (WidgetTester tester) async {
      // Set today as March 7, 2025
      final testDate = DateTime(2025, 3, 7);

      // Create test stats with max freezes already reached
      final initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          // 6 previous days
          LocalAudioCompleted(
              id: '1', timestamp: DateTime(2025, 3, 1).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '2', timestamp: DateTime(2025, 3, 2).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '3', timestamp: DateTime(2025, 3, 3).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '4', timestamp: DateTime(2025, 3, 4).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '5', timestamp: DateTime(2025, 3, 5).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '6', timestamp: DateTime(2025, 3, 6).millisecondsSinceEpoch),
        ],
        streakCurrent: 6,
        streakLongest: 10,
        totalTracksCompleted: 6,
        totalTimeListened: 360,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 2, // Already at max
        maxStreakFreezes: 2, // Max is 2
        freezeUsageDates: [],
      );

      // Initialize stats manager with test data
      var testStatsService = StatsService(
        httpApiService: HttpApiService(),
        prefs: prefs,
      );
      statsManager.setStatsServiceForTesting(testStatsService);
      await statsManager.initializeForTesting(statsService: testStatsService);
      statsManager.setStatsForTesting(initialStats);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagsProvider.overrideWith(
                () => TestFeatureFlagsNotifier(isStreakFreezeEnabled: true)),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      // Simulate completing 7th day meditation
                      final payload = {
                        TypeConstants.trackIdKey: 'track-7',
                        TypeConstants.timestampIdKey:
                            testDate.millisecondsSinceEpoch,
                        TypeConstants.durationIdKey: 60000, // 1 minute
                      };
                      await handleStats(payload, ref: ref);
                    },
                    child: const Text('Complete Session'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to complete session (reaching 7-day milestone)
      await tester.tap(find.text('Complete Session'));
      await tester.pumpAndSettle();

      // Verify NO additional freeze was awarded (at max)
      final updatedStats = await statsManager.localAllStats;
      expect(updatedStats.streakFreezes, 2,
          reason: 'Should remain at max freezes (no additional award)');
      expect(updatedStats.streakCurrent, 7,
          reason: 'Should still update streak');
    });

    testWidgets('should only award freeze on exact 7-day multiples',
        (WidgetTester tester) async {
      // Test day 8 (not a 7-day multiple)
      final testDate = DateTime(2025, 3, 8);

      // Create test stats at 8-day streak (not a multiple of 7)
      final initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          // 7 previous days
          LocalAudioCompleted(
              id: '1', timestamp: DateTime(2025, 3, 1).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '2', timestamp: DateTime(2025, 3, 2).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '3', timestamp: DateTime(2025, 3, 3).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '4', timestamp: DateTime(2025, 3, 4).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '5', timestamp: DateTime(2025, 3, 5).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '6', timestamp: DateTime(2025, 3, 6).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '7', timestamp: DateTime(2025, 3, 7).millisecondsSinceEpoch),
        ],
        streakCurrent: 7,
        streakLongest: 10,
        totalTracksCompleted: 7,
        totalTimeListened: 420,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 1, // Has 1 from day 7
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      // Initialize stats manager with test data
      var testStatsService = StatsService(
        httpApiService: HttpApiService(),
        prefs: prefs,
      );
      statsManager.setStatsServiceForTesting(testStatsService);
      await statsManager.initializeForTesting(statsService: testStatsService);
      statsManager.setStatsForTesting(initialStats);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureFlagsProvider.overrideWith(
                () => TestFeatureFlagsNotifier(isStreakFreezeEnabled: true)),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      // Simulate completing 8th day meditation (not a 7-day multiple)
                      final payload = {
                        TypeConstants.trackIdKey: 'track-8',
                        TypeConstants.timestampIdKey:
                            testDate.millisecondsSinceEpoch,
                        TypeConstants.durationIdKey: 60000, // 1 minute
                      };
                      await handleStats(payload, ref: ref);
                    },
                    child: const Text('Complete Day 8'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to complete 8th day session
      await tester.tap(find.text('Complete Day 8'));
      await tester.pumpAndSettle();

      // Verify NO freeze was awarded (not a 7-day multiple)
      final updatedStats = await statsManager.localAllStats;
      expect(updatedStats.streakFreezes, 1,
          reason: 'Should not award freeze on day 8 (not multiple of 7)');
      expect(updatedStats.streakCurrent, 8,
          reason: 'Should still update streak to 8');
    });
  });
}
