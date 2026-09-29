import 'package:flutter_test/flutter_test.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/views/player/session_completion_gate.dart';

PlaybackState _state({required bool completed, int positionMs = 600000}) {
  return PlaybackState(
    isPlaying: !completed,
    isBuffering: false,
    isSeeking: false,
    isCompleted: completed,
    position: positionMs,
    duration: 600000,
    speed: Speed(speed: 1),
    volume: 100,
    track: Track(
      id: 'welcome',
      title: 'Welcome',
      fileId: 'f1',
      description: '',
      imageUrl: '',
      artist: '',
    ),
  );
}

void main() {
  final completed = _state(completed: true);

  late SessionCompletionGate gate;

  setUp(() {
    gate = SessionCompletionGate()..reset();
  });

  group('previous session left isCompleted in the shared state', () {
    test('is ignored when the player opens', () {
      expect(gate.isSessionComplete(completed), isFalse);
    });

    test('is ignored when it flickers back while the new track loads', () {
      // play() resets the state, then iOS re-emits the old completed state
      // until setUrl clears it.
      gate.completionChanged(false);
      gate.completionChanged(true);
      expect(gate.isSessionComplete(completed), isFalse);
    });

    test('is ignored while it survives loading, until the state moves on', () {
      // Android: the stale state stays until the new track's first poll.
      gate.trackLoaded(isCompleted: true);
      expect(gate.isSessionComplete(completed), isFalse);

      gate.completionChanged(false);
      expect(gate.isSessionComplete(_state(completed: false)), isFalse);
      gate.completionChanged(true);
      expect(gate.isSessionComplete(completed), isTrue);
    });
  });

  test('opens for the completion of this screen\'s track', () {
    gate.trackLoaded(isCompleted: false);
    expect(gate.isSessionComplete(_state(completed: false)), isFalse);

    gate.completionChanged(true);
    expect(gate.isSessionComplete(completed), isTrue);
  });

  test('replaying the same track still needs a fresh completion', () {
    // Welcome completed, closed, Welcome played again: same track id, so only
    // the load/not-completed sequence tells the sessions apart.
    expect(gate.isSessionComplete(completed), isFalse);
    gate.trackLoaded(isCompleted: false);
    gate.completionChanged(true);
    expect(gate.isSessionComplete(completed), isTrue);
  });

  test('ignores completions at or under five seconds', () {
    gate.trackLoaded(isCompleted: false);
    gate.completionChanged(true);
    expect(
      gate.isSessionComplete(_state(completed: true, positionMs: 5000)),
      isFalse,
    );
    expect(
      gate.isSessionComplete(_state(completed: true, positionMs: 5001)),
      isTrue,
    );
  });

  test('a playback retry disarms until the retried track loads', () {
    gate.trackLoaded(isCompleted: false);
    gate.reset();
    gate.completionChanged(false);
    gate.completionChanged(true);
    expect(gate.isSessionComplete(completed), isFalse);

    gate.trackLoaded(isCompleted: false);
    gate.completionChanged(true);
    expect(gate.isSessionComplete(completed), isTrue);
  });
}
