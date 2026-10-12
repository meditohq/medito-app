import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/player/playback_request.dart';
import 'package:medito/utils/pending_end_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const request = PlaybackRequest(
    trackId: 'track1',
    fileId: 'file1',
    title: 'Sleep',
    description: '',
    coverUrl: '',
    remoteUrl: 'https://example.com/a.mp3',
    duration: 3600000,
    hasBackgroundSound: false,
    guideName: 'None',
  );
  final started = DateTime(2026, 10, 12, 22);
  final finishedMs = started
      .add(const Duration(hours: 1))
      .millisecondsSinceEpoch;

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('a completed session is returned once, with its prior stats', () async {
    final prior = LocalAllStats.empty();
    await PendingEndScreen.start(prefs, request, prior, now: started);
    await PendingEndScreen.markCompleted(
      prefs,
      fileId: 'file1',
      timestampMs: finishedMs,
    );

    final entry = await PendingEndScreen.takeCompleted(
      prefs,
      now: started.add(const Duration(hours: 8)),
    );
    expect(entry?.request, request);
    expect(entry?.priorStats?.toJson(), prior.toJson());
    expect(entry?.completedAt, DateTime.fromMillisecondsSinceEpoch(finishedMs));
    expect(await PendingEndScreen.takeCompleted(prefs), isNull);
  });

  test('a session that never completed is not shown', () async {
    await PendingEndScreen.start(prefs, request, null, now: started);
    expect(
      await PendingEndScreen.takeCompleted(
        prefs,
        now: started.add(const Duration(minutes: 5)),
      ),
      isNull,
    );
    // Still there for a completion replayed later in this launch.
    expect(prefs.getString(PendingEndScreen.prefsKey), isNotNull);
  });

  test('another file or an older completion does not claim it', () async {
    await PendingEndScreen.start(prefs, request, null, now: started);
    await PendingEndScreen.markCompleted(
      prefs,
      fileId: 'other',
      timestampMs: finishedMs,
    );
    await PendingEndScreen.markCompleted(
      prefs,
      fileId: 'file1',
      timestampMs: started
          .subtract(const Duration(minutes: 1))
          .millisecondsSinceEpoch,
    );
    expect(
      await PendingEndScreen.takeCompleted(
        prefs,
        now: started.add(const Duration(hours: 2)),
      ),
      isNull,
    );
  });

  test('a stale completion is dropped', () async {
    await PendingEndScreen.start(prefs, request, null, now: started);
    await PendingEndScreen.markCompleted(
      prefs,
      fileId: 'file1',
      timestampMs: finishedMs,
    );
    expect(
      await PendingEndScreen.takeCompleted(
        prefs,
        now: started.add(const Duration(days: 2)),
      ),
      isNull,
    );
    expect(prefs.getString(PendingEndScreen.prefsKey), isNull);
  });

  test('marking completed notifies listeners', () async {
    var notified = 0;
    void listener() => notified++;
    PendingEndScreen.completions.addListener(listener);
    addTearDown(() => PendingEndScreen.completions.removeListener(listener));

    await PendingEndScreen.start(prefs, request, null, now: started);
    await PendingEndScreen.markCompleted(
      prefs,
      fileId: 'file1',
      timestampMs: finishedMs,
    );
    expect(notified, 1);
  });
}
