import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/audio_completion_tracker.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/utils/stats_updater.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stats_manager_test.mocks.dart';

/// A completion the platform still has on disk is replayed on the next launch
/// (Android persists it natively, iOS keeps a pending payload). By then the
/// process-local guard in [handleStats] is gone, so the replay used to be
/// appended to the history a second time: one session counted twice in the
/// counters, the calendar and the streak.
///
/// The durable record is the identity of a session, so recording it twice must
/// be a no-op.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const durationMs = 10 * 60 * 1000;
  final completedAt = DateTime(2026, 9, 6, 9, 15);
  final trackId = 'track-replayed-1';

  late StatsManager statsManager;
  late MockStatsService mockStatsService;

  Future<void> boot() async {
    mockStatsService = MockStatsService();
    when(mockStatsService.postStats(any)).thenAnswer((_) async {});
    when(
      mockStatsService.fetchAllStats(),
    ).thenAnswer((_) async => LocalAllStats.empty());

    statsManager = StatsManager();
    statsManager.resetForTesting();
    statsManager.setStatsServiceForTesting(mockStatsService);
    await statsManager.initializeForTesting(statsService: mockStatsService);
    statsManager.setCurrentDateForTesting(completedAt);
  }

  /// Drops every in-memory copy, the way a process death would: the next read
  /// comes from SharedPreferences and the platform replays its own record.
  Future<void> restartProcess() async {
    statsManager.resetForTesting();
    await statsManager.initializeForTesting(statsService: mockStatsService);
    statsManager.setCurrentDateForTesting(completedAt);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await boot();
  });

  tearDown(() => statsManager.resetForTesting());

  group('a replayed completion is recorded once', () {
    test('the tracker reports a session it already holds', () async {
      final recorded = LocalAudioCompleted(
        id: trackId,
        timestamp: completedAt.millisecondsSinceEpoch,
      );

      final stats = AudioCompletionTracker.updateStatsWithCompletedAudio(
        stats: null,
        audioCompleted: recorded,
        duration: durationMs,
      );

      expect(AudioCompletionTracker.isAlreadyRecorded(stats, recorded), isTrue);
      expect(AudioCompletionTracker.isAlreadyRecorded(null, recorded), isFalse);
      expect(
        AudioCompletionTracker.isAlreadyRecorded(
          stats,
          recorded.copyWith(
            timestamp:
                recorded.timestamp + const Duration(hours: 1).inMilliseconds,
          ),
        ),
        isFalse,
      );
    });

    test(
      'StatsManager ignores the same id + timestamp after a restart',
      () async {
        final recorded = LocalAudioCompleted(
          id: trackId,
          timestamp: completedAt.millisecondsSinceEpoch,
        );

        await statsManager.addAudioCompleted(recorded, durationMs);
        var stats = await statsManager.localAllStats;
        expect(stats.audioCompleted, hasLength(1));
        expect(stats.totalTracksCompleted, 1);

        // The platform replays the persisted completion in the next process.
        await restartProcess();
        await statsManager.addAudioCompleted(recorded, durationMs);

        stats = await statsManager.localAllStats;
        expect(stats.audioCompleted, hasLength(1));
        expect(stats.totalTracksCompleted, 1);
        expect(stats.totalTimeListened, durationMs);
      },
    );

    test(
      'a replayed cross-midnight session keeps its re-anchored identity',
      () async {
        // Ends at 00:05, so it is re-anchored to the evening it started: the
        // replay has to match that stored timestamp, not the raw one.
        final end = DateTime(2026, 9, 7, 0, 5);
        final recorded = LocalAudioCompleted(
          id: trackId,
          timestamp: end.millisecondsSinceEpoch,
        );

        await statsManager.addAudioCompleted(recorded, durationMs);
        var stats = await statsManager.localAllStats;
        expect(stats.audioCompleted, hasLength(1));
        expect(stats.totalTracksCompleted, 1);

        await restartProcess();
        await statsManager.addAudioCompleted(recorded, durationMs);

        stats = await statsManager.localAllStats;
        expect(stats.audioCompleted, hasLength(1));
        expect(stats.totalTracksCompleted, 1);
        expect(stats.totalTimeListened, durationMs);
      },
    );

    test('a genuinely new completion of the same track still counts', () async {
      await statsManager.addAudioCompleted(
        LocalAudioCompleted(
          id: trackId,
          timestamp: completedAt.millisecondsSinceEpoch,
        ),
        durationMs,
      );
      await restartProcess();
      await statsManager.addAudioCompleted(
        LocalAudioCompleted(
          id: trackId,
          timestamp: completedAt
              .add(const Duration(hours: 2))
              .millisecondsSinceEpoch,
        ),
        durationMs,
      );

      final stats = await statsManager.localAllStats;
      expect(stats.audioCompleted, hasLength(2));
      expect(stats.totalTracksCompleted, 2);
      expect(stats.totalTimeListened, durationMs * 2);
    });

    test('handleStats records the replayed payload once', () async {
      final payload = {
        TypeConstants.trackIdKey: trackId,
        TypeConstants.durationIdKey: durationMs,
        TypeConstants.fileIdKey: 'file-replayed-1',
        TypeConstants.guideIdKey: 'guide-1',
        TypeConstants.timestampIdKey: completedAt.millisecondsSinceEpoch,
        TypeConstants.titleKey: 'Replayed',
      };

      await handleStats(payload, statsManager: statsManager);
      var stats = await statsManager.localAllStats;
      expect(stats.totalTracksCompleted, 1);

      // Next launch: no navigator, empty in-memory guard, same payload.
      await restartProcess();
      clearRecordedCompletionsForTesting();
      await handleStats(payload, statsManager: statsManager);

      stats = await statsManager.localAllStats;
      expect(stats.audioCompleted, hasLength(1));
      expect(stats.totalTracksCompleted, 1);
      expect(stats.totalTimeListened, durationMs);
    });
  });
}
