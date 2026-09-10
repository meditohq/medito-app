import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stats_manager_test.mocks.dart';

/// Regression tests for a support case (Sept 2026) where a long-time user's
/// lifetime counters collapsed to a handful of sessions while the completion
/// history survived. Root cause: a completion was recorded while the
/// in-memory stats were still null (fresh engine, sync short-circuited), so
/// the tracker started from an empty object, saved it over the local copy and
/// POSTed it; the following merge then took the counters from that fresh copy
/// because it carried the newer `updated` stamp.
void main() {
  const oneDay = Duration(days: 1);
  final today = DateTime(2026, 9, 6, 12);

  late StatsManager statsManager;
  late MockStatsService mockStatsService;

  LocalAllStats historyStats({int days = 300}) {
    final completions = List.generate(
      days,
      (i) => LocalAudioCompleted(
        id: 'track-$i',
        timestamp: today.subtract(oneDay * i).millisecondsSinceEpoch,
      ),
    );
    return LocalAllStats.empty().copyWith(
      streakCurrent: days,
      streakLongest: 312,
      totalTracksCompleted: 1353,
      totalTimeListened: 200 * 60 * 60 * 1000,
      audioCompleted: completions,
      tracksChecked: completions.map((c) => c.id).toList(),
      updated: today.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
  }

  Future<void> boot(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    mockStatsService = MockStatsService();
    when(mockStatsService.postStats(any)).thenAnswer((_) async {});
    statsManager = StatsManager();
    statsManager.resetForTesting();
    statsManager.setStatsServiceForTesting(mockStatsService);
    await statsManager.initializeForTesting(statsService: mockStatsService);
    statsManager.setCurrentDateForTesting(today);
  }

  tearDown(() => statsManager.resetForTesting());

  group('completion arriving before in-memory stats are loaded', () {
    test('sync TTL short-circuit must not wipe the on-disk history', () async {
      final history = historyStats();
      await boot({
        SharedPreferenceConstants.localAllStatsKey: jsonEncode(
          history.toJson(),
        ),
        // A sync finished seconds ago, so sync() returns without a fetch.
        SharedPreferenceConstants.statsLastSyncedAt: today
            .subtract(const Duration(seconds: 5))
            .millisecondsSinceEpoch,
      });
      when(mockStatsService.fetchAllStats()).thenAnswer((_) async {
        fail('sync should short-circuit within the TTL');
      });

      await statsManager.addAudioCompleted(
        LocalAudioCompleted(
          id: 'new-track',
          timestamp: today.millisecondsSinceEpoch,
        ),
        10 * 60 * 1000,
      );

      final result = statsManager.currentStats!;
      expect(result.totalTracksCompleted, history.totalTracksCompleted + 1);
      expect(
        result.totalTimeListened,
        history.totalTimeListened + 10 * 60 * 1000,
      );
      expect(result.audioCompleted!.length, history.audioCompleted!.length + 1);
      expect(result.streakLongest, greaterThanOrEqualTo(312));

      final posted =
          verify(mockStatsService.postStats(captureAny)).captured.single
              as LocalAllStats;
      expect(posted.totalTracksCompleted, history.totalTracksCompleted + 1);
    });

    test('sync lock held by another sync must not wipe the history', () async {
      final history = historyStats();
      await boot({
        SharedPreferenceConstants.localAllStatsKey: jsonEncode(
          history.toJson(),
        ),
        // Foreground forced sync is mid-flight and owns the lock.
        'stats_sync_lock': today.millisecondsSinceEpoch,
      });
      when(mockStatsService.fetchAllStats()).thenAnswer((_) async {
        fail('sync should not run while the lock is held');
      });

      await statsManager.addAudioCompleted(
        LocalAudioCompleted(
          id: 'new-track',
          timestamp: today.millisecondsSinceEpoch,
        ),
        10 * 60 * 1000,
      );

      expect(
        statsManager.currentStats!.totalTracksCompleted,
        history.totalTracksCompleted + 1,
      );
      expect(
        statsManager.currentStats!.audioCompleted!.length,
        history.audioCompleted!.length + 1,
      );
    });
  });

  group('merge reconciles lifetime counters', () {
    test('fresh local copy with newer `updated` does not win', () async {
      await boot({});
      final history = historyStats();
      final fresh = LocalAllStats.empty().copyWith(
        totalTracksCompleted: 1,
        totalTimeListened: 9 * 60 * 1000,
        streakCurrent: 1,
        streakLongest: 1,
        audioCompleted: [
          LocalAudioCompleted(
            id: 'new-track',
            timestamp: today.millisecondsSinceEpoch,
          ),
        ],
        tracksChecked: ['new-track'],
        updated: today.millisecondsSinceEpoch,
      );
      statsManager.setStatsForTesting(fresh);
      when(mockStatsService.fetchAllStats()).thenAnswer((_) async => history);

      await statsManager.sync(force: true);

      final merged = statsManager.currentStats!;
      expect(merged.totalTracksCompleted, history.totalTracksCompleted);
      expect(merged.totalTimeListened, history.totalTimeListened);
      expect(merged.streakLongest, history.streakLongest);
      expect(merged.audioCompleted!.length, history.audioCompleted!.length + 1);
      expect(merged.streakCurrent, history.audioCompleted!.length);
    });

    test('fresh remote copy with newer `updated` does not win', () async {
      await boot({});
      final history = historyStats();
      final fresh = LocalAllStats.empty().copyWith(
        totalTracksCompleted: 1,
        totalTimeListened: 9 * 60 * 1000,
        streakLongest: 1,
        audioCompleted: [
          LocalAudioCompleted(
            id: 'new-track',
            timestamp: today.millisecondsSinceEpoch,
          ),
        ],
        tracksChecked: ['new-track'],
        updated: today.millisecondsSinceEpoch,
      );
      statsManager.setStatsForTesting(history);
      when(mockStatsService.fetchAllStats()).thenAnswer((_) async => fresh);

      await statsManager.sync(force: true);

      final merged = statsManager.currentStats!;
      expect(merged.totalTracksCompleted, history.totalTracksCompleted);
      expect(merged.totalTimeListened, history.totalTimeListened);
      expect(merged.streakLongest, history.streakLongest);
    });

    test('counter never reports fewer completions than the history', () async {
      await boot({});
      final history = historyStats().copyWith(totalTracksCompleted: 5);
      statsManager.setStatsForTesting(history);
      when(mockStatsService.fetchAllStats()).thenAnswer((_) async => history);

      await statsManager.sync(force: true);

      expect(
        statsManager.currentStats!.totalTracksCompleted,
        history.audioCompleted!.length,
      );
    });
  });
}
