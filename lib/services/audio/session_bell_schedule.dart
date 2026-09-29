/// One-shot cues follow media time, never wall-clock time. Seeking past a cue
/// consumes it; seeking to the beginning starts a fresh session.
class SessionBellSchedule {
  bool _started = false;
  bool _middle = false;
  bool _end = false;

  // The asset lasts six seconds, including its silent tail. Convert that
  // wall-clock duration to media time so faster playback still leaves room.
  Duration _endPosition(Duration duration, double speed) {
    final lead = Duration(microseconds: (6000000 * speed).round());
    final position = duration - lead;
    return position > duration ~/ 2 ? position : duration ~/ 2;
  }

  void reset() {
    _started = false;
    _middle = false;
    _end = false;
  }

  void seek(Duration position, Duration duration, {double speed = 1}) {
    if (position == Duration.zero) {
      reset();
    } else {
      _started = true;
      _middle = duration > Duration.zero && position >= duration ~/ 2;
      _end =
          duration > Duration.zero && position >= _endPosition(duration, speed);
    }
  }

  bool update(Duration position, Duration duration, {double speed = 1}) {
    if (duration <= Duration.zero || position >= duration) return false;
    if (!_started) {
      _started = true;
      _middle = position >= duration ~/ 2;
      _end = position >= _endPosition(duration, speed);
      return position < const Duration(seconds: 2);
    }
    if (!_end && position >= _endPosition(duration, speed)) {
      _end = true;
      _middle = true;
      return true;
    }
    if (!_middle && position >= duration ~/ 2 && position < duration) {
      _middle = true;
      return true;
    }
    return false;
  }
}
