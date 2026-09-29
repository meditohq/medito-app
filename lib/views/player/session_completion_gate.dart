import 'package:medito/src/audio_pigeon.g.dart';

/// Decides when [PlayerView] may treat the shared audio state's completion as
/// the end of its own session.
///
/// `audioStateProvider` is global and outlives the player screen, so a new
/// player opens holding whatever the previous session left behind — after a
/// finished track that is `isCompleted` at full position (the onboarding
/// meditation never stops the player, and a stop only clears it
/// asynchronously). Acting on that opened the end screen ~50ms after the
/// player, with the new track playing behind it.
///
/// A completion only belongs to this session once this screen's track has
/// loaded and the state has read not-completed at least once since: every real
/// session passes through that before it can finish, even when it replays the
/// same track, so no track id comparison is needed.
class SessionCompletionGate {
  /// Shorter "completions" are load/error artefacts, not a finished session.
  static const minCompletedPositionMs = 5000;

  bool _trackLoaded = false;
  bool _armed = false;

  /// Playback is (re)starting on this screen: nothing seen so far counts.
  void reset() {
    _trackLoaded = false;
    _armed = false;
  }

  /// This screen's track has loaded; [isCompleted] is the shared state now.
  void trackLoaded({required bool isCompleted}) {
    _trackLoaded = true;
    completionChanged(isCompleted);
  }

  /// Call on every change of the shared state's `isCompleted`.
  void completionChanged(bool isCompleted) {
    if (_trackLoaded && !isCompleted) _armed = true;
  }

  /// Whether [state] is the completion of this screen's session.
  bool isSessionComplete(PlaybackState state) =>
      _armed && state.isCompleted && state.position > minCompletedPositionMs;
}
