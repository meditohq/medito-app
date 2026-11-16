import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stats_manager_test.mocks.dart';

/// Deleting the last remaining session used to be invisible on the next
/// launch: the local write was skipped whenever the resulting
/// `totalTracksCompleted` was 0, so the old copy (with the session) stayed on
/// disk. The deletion reached the server, but the next launch read the stale
/// local copy, and the merge treats a non-empty local history as the winner —
/// so the deleted session came back, locally and on the server.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StatsManager statsManager;
  late MockStatsService mockStatsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockStatsService = MockStatsService();
    statsManager = StatsManager();
    statsManager.setStatsServiceForTesting(mockStatsService);
    await statsManager.initializeForTesting(statsService: mockStatsService);
    statsManager.setCurrentDateForTesting(DateTime(2026, 4, 28, 20));
    when(mockStatsService.postStats(any)).thenAnswer((_) async => {});
  });

  tearDown(() {
    statsManager.resetForTesting();
  });

  Future<Map<String, dynamic>?> readSavedStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(SharedPreferenceConstants.localAllStatsKey);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  group('Deleting the last session', () {
    test(
      'is written to disk, so it does not return on the next launch',
      () async {
        final timestamp = DateTime(2026, 4, 28, 8).millisecondsSinceEpoch;
        final session = LocalAudioCompleted(
          id: 'track-1',
          timestamp: timestamp,
        );

        statsManager.setStatsForTesting(LocalAllStats.empty());
        await statsManager.addAudioCompleted(session, 600000);

        var saved = await readSavedStats();
        expect(saved?['totalTracksCompleted'], 1);
        expect((saved?['audioCompleted'] as List).length, 1);

        await statsManager.removeAudioCompleted(session);

        saved = await readSavedStats();
        expect(
          saved?['totalTracksCompleted'],
          0,
          reason: 'the empty history must replace the saved copy',
        );
        expect(
          (saved?['audioCompleted'] as List),
          isEmpty,
          reason: 'the deleted session must not stay in the saved history',
        );

        // A fresh manager (i.e. the next app launch) reads the deletion back.
        statsManager.resetForTesting();
        await statsManager.initializeForTesting(statsService: mockStatsService);
        final reloaded = await statsManager.readLocalStats();
        expect(reloaded.totalTracksCompleted, 0);
        expect(reloaded.audioCompleted, isEmpty);
      },
    );

    test('keeps the other sessions and their order', () async {
      final first = LocalAudioCompleted(
        id: 'track-1',
        timestamp: DateTime(2026, 4, 26, 8).millisecondsSinceEpoch,
      );
      final second = LocalAudioCompleted(
        id: 'track-2',
        timestamp: DateTime(2026, 4, 27, 8).millisecondsSinceEpoch,
      );

      statsManager.setStatsForTesting(LocalAllStats.empty());
      await statsManager.addAudioCompleted(first, 600000);
      await statsManager.addAudioCompleted(second, 600000);

      await statsManager.removeAudioCompleted(first);

      final saved = await readSavedStats();
      expect(saved?['totalTracksCompleted'], 1);
      final savedSessions = saved?['audioCompleted'] as List;
      expect(savedSessions, hasLength(1));
      expect((savedSessions.single as Map)['id'], 'track-2');
    });

    test(
      'deleting a session that is not there leaves the saved copy alone',
      () async {
        final kept = LocalAudioCompleted(
          id: 'track-1',
          timestamp: DateTime(2026, 4, 26, 8).millisecondsSinceEpoch,
        );
        final missing = LocalAudioCompleted(
          id: 'track-9',
          timestamp: DateTime(2026, 4, 20, 8).millisecondsSinceEpoch,
        );

        statsManager.setStatsForTesting(LocalAllStats.empty());
        await statsManager.addAudioCompleted(kept, 600000);

        await statsManager.removeAudioCompleted(missing);

        final saved = await readSavedStats();
        expect(saved?['totalTracksCompleted'], 1);
        expect((saved?['audioCompleted'] as List).length, 1);
      },
    );
  });

  group('An empty in-memory copy still cannot wipe the saved history', () {
    test('a write from an unloaded stats object is skipped', () async {
      final session = LocalAudioCompleted(
        id: 'track-1',
        timestamp: DateTime(2026, 4, 26, 8).millisecondsSinceEpoch,
      );

      statsManager.setStatsForTesting(LocalAllStats.empty());
      await statsManager.addAudioCompleted(session, 600000);

      // Simulates the case the guard exists for: a fresh, all-zero copy in
      // memory while the real history is on disk.
      statsManager.setStatsForTesting(LocalAllStats.empty());
      await statsManager.addTrackChecked('track-1');

      final saved = await readSavedStats();
      expect(
        saved?['totalTracksCompleted'],
        1,
        reason: 'the saved history must survive an empty in-memory copy',
      );
      expect((saved?['audioCompleted'] as List).length, 1);
    });
  });
}
