import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stats_manager_test.mocks.dart';

/// Covers the [StatsManager.addAudioCompleted] `skipPost` flag and the
/// companion [StatsManager.flushPendingPost] introduced for the bulk
/// backfill flow. The original bug: the calendar widget was firing one
/// network POST per inserted day, so backfilling 30 days made 30 sequential
/// round-trips. These tests pin down the new contract:
///   * `skipPost: true` mutates local state but never hits the network
///   * `flushPendingPost` posts at most once and only when there's
///     unsynced state
///   * The default behaviour of `addAudioCompleted` is unchanged
void main() {
  late StatsManager statsManager;
  late MockStatsService mockStatsService;
  late DateTime today;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockStatsService = MockStatsService();
    statsManager = StatsManager();
    statsManager.setStatsServiceForTesting(mockStatsService);
    await statsManager.initializeForTesting(statsService: mockStatsService);

    today = DateTime(2026, 4, 28);
    statsManager.setCurrentDateForTesting(today);

    when(mockStatsService.postStats(any))
        .thenAnswer((_) async => Future.value());

    statsManager.setStatsForTesting(
      LocalAllStats.empty().copyWith(streakCurrent: 0, streakLongest: 0),
    );
  });

  tearDown(() {
    statsManager.resetForTesting();
  });

  LocalAudioCompleted entryAt(DateTime t) =>
      LocalAudioCompleted(id: 'manual2', timestamp: t.millisecondsSinceEpoch);

  group('addAudioCompleted with skipPost', () {
    test('does not call postStats when skipPost is true', () async {
      await statsManager.addAudioCompleted(
        entryAt(DateTime(2026, 4, 27, 12)),
        10 * 60 * 1000,
        skipPost: true,
      );

      verifyNever(mockStatsService.postStats(any));
    });

    test('still saves stats locally and recalculates streak', () async {
      await statsManager.addAudioCompleted(
        entryAt(DateTime(2026, 4, 28, 12)),
        10 * 60 * 1000,
        skipPost: true,
      );

      final stats = statsManager.currentStats;
      expect(stats, isNotNull);
      expect(stats!.audioCompleted, isNotEmpty);
      expect(stats.streakCurrent, 1,
          reason: 'streak should be recalculated even when post is skipped');
    });

    test('default (skipPost: false) still posts — regression check', () async {
      await statsManager.addAudioCompleted(
        entryAt(DateTime(2026, 4, 28, 12)),
        10 * 60 * 1000,
      );

      verify(mockStatsService.postStats(any)).called(1);
    });

    test('many skipPost inserts produce zero network calls', () async {
      for (var d = 1; d <= 30; d++) {
        await statsManager.addAudioCompleted(
          entryAt(DateTime(2026, 4, d, 12)),
          5 * 60 * 1000,
          skipPost: true,
        );
      }
      verifyNever(mockStatsService.postStats(any));
      // …and all 30 entries are present locally.
      expect(statsManager.currentStats!.audioCompleted!.length, 30);
    });
  });

  group('flushPendingPost', () {
    test('is a no-op when no skipPost insert has happened', () async {
      await statsManager.flushPendingPost();
      verifyNever(mockStatsService.postStats(any));
    });

    test('posts once after a batch of skipPost inserts', () async {
      for (var d = 1; d <= 30; d++) {
        await statsManager.addAudioCompleted(
          entryAt(DateTime(2026, 4, d, 12)),
          5 * 60 * 1000,
          skipPost: true,
        );
      }

      await statsManager.flushPendingPost();
      verify(mockStatsService.postStats(any)).called(1);
    });

    test('a second flush after the first does not re-post', () async {
      await statsManager.addAudioCompleted(
        entryAt(DateTime(2026, 4, 28, 12)),
        10 * 60 * 1000,
        skipPost: true,
      );

      await statsManager.flushPendingPost();
      await statsManager.flushPendingPost();
      verify(mockStatsService.postStats(any)).called(1);
    });

    test('a non-skipPost insert after a flush still posts', () async {
      await statsManager.addAudioCompleted(
        entryAt(DateTime(2026, 4, 27, 12)),
        10 * 60 * 1000,
        skipPost: true,
      );
      await statsManager.flushPendingPost();
      clearInteractions(mockStatsService);

      await statsManager.addAudioCompleted(
        entryAt(DateTime(2026, 4, 28, 12)),
        10 * 60 * 1000,
      );
      verify(mockStatsService.postStats(any)).called(1);
    });
  });
}
