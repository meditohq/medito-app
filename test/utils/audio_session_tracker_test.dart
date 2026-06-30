import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/utils/audio_session_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures what the tracker would have logged, in order.
class _LoggedEvent {
  _LoggedEvent(this.name, this.params);
  final String name;
  final Map<String, Object> params;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tracker = AudioSessionTracker.instance;
  late List<_LoggedEvent> events;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    events = [];
    AudioSessionTracker.logSink = (name, params) async {
      events.add(_LoggedEvent(name, params));
    };
    tracker.resetForTesting();
  });

  List<_LoggedEvent> of(String name) =>
      events.where((e) => e.name == name).toList();

  Future<String?> persisted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SharedPreferenceConstants.incompleteAudioSession);
  }

  group('started', () {
    test('fires once with the file/guide/duration params', () async {
      await tracker.onStarted(fileId: 'f1', guide: 'Will', durationMs: 600000);

      final started = of(AnalyticsEventConstants.audioSessionStarted);
      expect(started, hasLength(1));
      expect(
        started.first.params[AnalyticsEventConstants.paramAudioFileId],
        'f1',
      );
      expect(
        started.first.params[AnalyticsEventConstants.paramAudioFileGuide],
        'Will',
      );
      expect(
        started.first.params[AnalyticsEventConstants.paramAudioFileDuration],
        600000,
      );
      // An in-progress record is persisted for crash recovery.
      expect(await persisted(), isNotNull);
    });

    test('missing guide falls back to unknown', () async {
      await tracker.onStarted(fileId: 'f1', guide: null, durationMs: 1000);
      expect(
        of(
          AnalyticsEventConstants.audioSessionStarted,
        ).first.params[AnalyticsEventConstants.paramAudioFileGuide],
        'unknown',
      );
    });
  });

  group('completed', () {
    test('clears the record and suppresses a later abandon', () async {
      await tracker.onStarted(fileId: 'f1', guide: 'g', durationMs: 1000);
      await tracker.onCompleted();
      expect(await persisted(), isNull);

      await tracker.onStopped(); // close player after completing
      expect(of(AnalyticsEventConstants.audioSessionAbandoned), isEmpty);
    });
  });

  group('abandoned', () {
    test(
      'stop midway fires abandoned with bucketed percent + elapsed',
      () async {
        await tracker.onStarted(fileId: 'f1', guide: 'g', durationMs: 600000);
        // 252s of 600s => 42% => bucket 40.
        tracker.onPositionUpdate(
          positionMs: 252000,
          durationMs: 600000,
          isPlaying: false,
          isCompleted: false,
        );
        await tracker.onStopped();

        final ab = of(AnalyticsEventConstants.audioSessionAbandoned);
        expect(ab, hasLength(1));
        expect(
          ab.first.params[AnalyticsEventConstants.paramPercentCompleted],
          40,
        );
        expect(
          ab.first.params[AnalyticsEventConstants.paramElapsedSeconds],
          252,
        );
        expect(await persisted(), isNull);
      },
    );

    test('percent is clamped to 90 even past ~95%', () async {
      await tracker.onStarted(fileId: 'f1', guide: 'g', durationMs: 1000);
      tracker.onPositionUpdate(
        positionMs: 980,
        durationMs: 1000,
        isPlaying: false,
        isCompleted: false,
      );
      await tracker.onStopped();
      expect(
        of(
          AnalyticsEventConstants.audioSessionAbandoned,
        ).first.params[AnalyticsEventConstants.paramPercentCompleted],
        90,
      );
    });

    test('fires at most once per session', () async {
      await tracker.onStarted(fileId: 'f1', guide: 'g', durationMs: 1000);
      tracker.onPositionUpdate(
        positionMs: 500,
        durationMs: 1000,
        isPlaying: false,
        isCompleted: false,
      );
      await tracker.onStopped();
      await tracker.onStopped();
      await tracker.onAppBackgrounded();
      expect(of(AnalyticsEventConstants.audioSessionAbandoned), hasLength(1));
    });

    test(
      'player-completed position is not double-counted as abandon',
      () async {
        await tracker.onStarted(fileId: 'f1', guide: 'g', durationMs: 1000);
        // Stream reports completion (race with the completion event path).
        tracker.onPositionUpdate(
          positionMs: 1000,
          durationMs: 1000,
          isPlaying: false,
          isCompleted: true,
        );
        await tracker.onStopped();
        expect(of(AnalyticsEventConstants.audioSessionAbandoned), isEmpty);
      },
    );
  });

  group('backgrounding / navigate-away', () {
    test('backgrounding while PLAYING does not abandon', () async {
      await tracker.onStarted(fileId: 'f1', guide: 'g', durationMs: 1000);
      tracker.onPositionUpdate(
        positionMs: 300,
        durationMs: 1000,
        isPlaying: true,
        isCompleted: false,
      );
      await tracker.onAppBackgrounded();
      expect(of(AnalyticsEventConstants.audioSessionAbandoned), isEmpty);
      // Session still alive and recoverable.
      expect(await persisted(), isNotNull);
    });

    test('backgrounding while paused abandons', () async {
      await tracker.onStarted(fileId: 'f1', guide: 'g', durationMs: 1000);
      tracker.onPositionUpdate(
        positionMs: 300,
        durationMs: 1000,
        isPlaying: false,
        isCompleted: false,
      );
      await tracker.onAppBackgrounded();
      expect(of(AnalyticsEventConstants.audioSessionAbandoned), hasLength(1));
    });

    test('navigate away while playing does not abandon', () async {
      await tracker.onStarted(fileId: 'f1', guide: 'g', durationMs: 1000);
      tracker.onPositionUpdate(
        positionMs: 300,
        durationMs: 1000,
        isPlaying: true,
        isCompleted: false,
      );
      await tracker.onPlayerClosed();
      expect(of(AnalyticsEventConstants.audioSessionAbandoned), isEmpty);
    });
  });

  group('switch track', () {
    test('starting a new track abandons the previous unfinished one', () async {
      await tracker.onStarted(fileId: 'f1', guide: 'g', durationMs: 1000);
      tracker.onPositionUpdate(
        positionMs: 200,
        durationMs: 1000,
        isPlaying: true,
        isCompleted: false,
      );
      await tracker.onStarted(fileId: 'f2', guide: 'g', durationMs: 1000);

      expect(of(AnalyticsEventConstants.audioSessionStarted), hasLength(2));
      final ab = of(AnalyticsEventConstants.audioSessionAbandoned);
      expect(ab, hasLength(1));
      expect(ab.first.params[AnalyticsEventConstants.paramAudioFileId], 'f1');
      expect(
        ab.first.params[AnalyticsEventConstants.paramPercentCompleted],
        20,
      );
    });
  });

  group('launch replay', () {
    test('fires abandoned from a leftover record and clears it', () async {
      // Seed a record as if a prior run was force-quit at 30%, then start a
      // fresh process (only the persisted record survives).
      SharedPreferences.setMockInitialValues({
        SharedPreferenceConstants.incompleteAudioSession:
            '{"fileId":"f9","guide":"Sky","durationMs":1000,'
            '"startMs":111,"lastPositionMs":300}',
      });
      tracker.resetForTesting();
      events.clear();

      await tracker.replayIfAbandoned();

      final ab = of(AnalyticsEventConstants.audioSessionAbandoned);
      expect(ab, hasLength(1));
      expect(ab.first.params[AnalyticsEventConstants.paramAudioFileId], 'f9');
      expect(
        ab.first.params[AnalyticsEventConstants.paramAudioFileGuide],
        'Sky',
      );
      expect(
        ab.first.params[AnalyticsEventConstants.paramPercentCompleted],
        30,
      );
      expect(await persisted(), isNull);
    });

    test('no record => no event', () async {
      await tracker.replayIfAbandoned();
      expect(events, isEmpty);
    });
  });
}
