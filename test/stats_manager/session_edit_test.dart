import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../stats_manager_test.mocks.dart';

void main() {
  late StatsManager manager;
  late MockStatsService service;
  final now = DateTime(2026, 11, 1, 12);
  final original = LocalAudioCompleted(
    id: 'guided',
    timestamp: DateTime(2026, 10, 30, 12).millisecondsSinceEpoch,
  );
  final other = LocalAudioCompleted(
    id: 'guided',
    timestamp: DateTime(2026, 10, 29, 12).millisecondsSinceEpoch,
  );
  final replacement = original.copyWith(
    timestamp: DateTime(2026, 10, 31, 12).millisecondsSinceEpoch,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = MockStatsService();
    manager = StatsManager();
    await manager.initializeForTesting(statsService: service);
    manager.setCurrentDateForTesting(now);
    manager.setStatsForTesting(
      LocalAllStats.empty().copyWith(
        audioCompleted: [original, other],
        totalTracksCompleted: 2,
        totalTimeListened: 1200000,
        tracksChecked: ['guided'],
      ),
    );
    when(service.postStats(any)).thenAnswer((_) async => {});
  });
  tearDown(() => manager.resetForTesting());

  for (final offline in [false, true]) {
    test(
      'session correction preserves totals and other plays, offline: $offline',
      () async {
        if (offline) {
          when(service.postStats(any)).thenThrow(Exception('offline'));
        }
        expect(
          await manager.replaceAudioCompleted(
            original: original,
            replacement: replacement,
          ),
          isTrue,
        );
        final stats = manager.currentStats!;
        expect(stats.audioCompleted!.map((e) => e.timestamp), [
          replacement.timestamp,
          other.timestamp,
        ]);
        expect(stats.audioCompleted!.map((e) => e.id), ['guided', 'guided']);
        expect(stats.totalTracksCompleted, 2);
        expect(stats.totalTimeListened, 1200000);
        expect(stats.tracksChecked, ['guided']);
        expect(stats.streakCurrent, 1);
        verify(service.postStats(any)).called(1);
      },
    );
  }
  test('stale entries do not replace a different session', () async {
    expect(
      await manager.replaceAudioCompleted(
        original: replacement,
        replacement: original,
      ),
      isFalse,
    );
    verifyNever(service.postStats(any));
    expect(
      manager.currentStats!.audioCompleted!.first.timestamp,
      original.timestamp,
    );
  });
  test('future and duplicate corrections leave history intact', () async {
    await expectLater(
      manager.replaceAudioCompleted(
        original: original,
        replacement: original.copyWith(
          timestamp: now.add(const Duration(days: 1)).millisecondsSinceEpoch,
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      manager.replaceAudioCompleted(original: original, replacement: other),
      throwsStateError,
    );
    verifyNever(service.postStats(any));
    expect(
      manager.currentStats!.audioCompleted!.first.timestamp,
      original.timestamp,
    );
  });
}
