import 'package:medito/models/player/playback_request.dart';

/// The two ways the home Timer runs: down from a chosen length, or up until
/// the user ends it.
enum TimerMode { countdown, stopwatch }

/// Track id of the old bell-only "Timer" track that the home shortcut opened
/// before the native timer existed. Navigation to it now opens [TimerView].
const kLegacyTimerTrackId = 'Hdu7YtWSmHtU4bDh';

/// Timer sessions are recorded in stats as `timer-<seconds>`. There is no
/// per-session duration in [LocalAudioCompleted], so the length lives in the
/// id and history can show "Timer · 20 min". Same character set as the other
/// synthetic ids (`streak-freeze`, `manual1`) the stats API already accepts.
const kTimerSessionIdPrefix = 'timer-';

/// Shortest timer session worth recording when the user ends it early.
const kMinRecordedTimerSession = Duration(minutes: 1);

/// A stopwatch has to be played as a finite file, so it runs this long before
/// finishing by itself. Far beyond any real sit (60-minute timers are already
/// abandoned 45% of the time), and the file is sparse so the length is free.
const kStopwatchMaxDuration = Duration(hours: 5);

/// Countdown lengths offered as one-tap chips, ordered as shown. These are the
/// most-started timer lengths (Sep 2026: 5 and 10 min were ~45% of starts,
/// then 3, 1, 15 and 20).
const kTimerPresetMinutes = [3, 5, 10, 15, 20];

/// Default countdown for a first-time user.
const kDefaultTimerMinutes = 10;

/// Longest countdown the picker offers.
const kMaxTimerHours = 4;

String timerSessionId(Duration duration) =>
    '$kTimerSessionIdPrefix${duration.inSeconds}';

bool isTimerSessionId(String id) => id.startsWith(kTimerSessionIdPrefix);

/// The recorded length of a timer session id, or null for any other id.
Duration? timerSessionDuration(String id) {
  if (!isTimerSessionId(id)) return null;
  final seconds = int.tryParse(id.substring(kTimerSessionIdPrefix.length));
  return seconds == null ? null : Duration(seconds: seconds);
}

/// Analytics file id, shaped like real ones (`<track>-<guide>-<ms>`) so the
/// existing session queries can split out the length.
String timerFileId(TimerMode mode, Duration duration) =>
    'timer-${mode.name}-${duration.inMilliseconds}';

extension TimerPlaybackRequest on PlaybackRequest {
  bool get isTimer => isTimerSessionId(trackId);

  TimerMode get timerMode =>
      fileId.startsWith('timer-${TimerMode.stopwatch.name}-')
      ? TimerMode.stopwatch
      : TimerMode.countdown;
}

/// Builds the request the regular player plays for a timer: the silent file
/// at [filePath] carries the session, bells and any background sound play on
/// top of it as for a track.
PlaybackRequest timerPlaybackRequest({
  required TimerMode mode,
  required Duration duration,
  required String filePath,
  required String title,
  String? coverUrl,
}) {
  return PlaybackRequest(
    trackId: timerSessionId(duration),
    fileId: timerFileId(
      mode,
      mode == TimerMode.stopwatch ? Duration.zero : duration,
    ),
    title: title,
    description: '',
    coverUrl: coverUrl ?? '',
    remoteUrl: Uri.file(filePath).toString(),
    duration: duration.inMilliseconds,
    hasBackgroundSound: true,
  );
}
