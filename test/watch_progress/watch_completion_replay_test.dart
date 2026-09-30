import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stats_manager_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StatsManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    manager = StatsManager()..resetForTesting();
    await manager.initializeForTesting(statsService: MockStatsService());
    manager.setStatsForTesting(LocalAllStats.empty());
  });

  tearDown(() => manager.resetForTesting());

  test('canonical watch timestamp is not normalized a second time', () async {
    final timestamp = DateTime(2026, 9, 30, 0, 2).millisecondsSinceEpoch;
    await manager.addAudioCompleted(
      LocalAudioCompleted(id: 'watch-track', timestamp: timestamp),
      600000,
      skipPost: true,
      deduplicate: true,
      timestampIsNormalized: true,
    );
    expect(manager.currentStats!.audioCompleted!.single.timestamp, timestamp);
  });

  for (final crossesMidnight in [false, true]) {
    test(
      'watch replay survives restart (crosses midnight: $crossesMidnight)',
      () async {
        final end = crossesMidnight
            ? DateTime(2026, 9, 30, 0, 4)
            : DateTime(2026, 9, 30, 12);
        const duration = 10 * 60 * 1000;
        final entry = LocalAudioCompleted(
          id: 'watch-track',
          timestamp: end.millisecondsSinceEpoch,
        );
        await manager.addAudioCompleted(
          entry,
          duration,
          skipPost: true,
          deduplicate: true,
        );

        // Simulate process death after local save but before native acknowledgement.
        manager.resetForTesting();
        await manager.initializeForTesting(statsService: MockStatsService());
        await manager.addAudioCompleted(
          entry,
          duration,
          skipPost: true,
          deduplicate: true,
        );

        final prefs = await SharedPreferences.getInstance();
        final saved = LocalAllStats.fromJson(
          jsonDecode(
                prefs.getString(SharedPreferenceConstants.localAllStatsKey)!,
              )
              as Map<String, dynamic>,
        );
        expect(saved.totalTracksCompleted, 1);
        expect(saved.totalTimeListened, duration);
        expect(saved.audioCompleted, hasLength(1));
        expect(
          saved.audioCompleted!.single.timestamp,
          entry.timestamp - (crossesMidnight ? duration : 0),
        );
      },
    );
  }
}
