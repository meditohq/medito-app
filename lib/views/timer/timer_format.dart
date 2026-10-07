import 'package:medito/l10n/app_localizations.dart';

/// `4:05`, `12:00` or `1:02:03`: a running clock.
String formatTimerClock(Duration duration) {
  final d = duration.isNegative ? Duration.zero : duration;
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

/// `20 min`, `1 h` or `1 h 30 min`: a session length, rounded down to the
/// minute.
String formatTimerLength(Duration duration, AppLocalizations l10n) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes ${l10n.min}';
  if (minutes == 0) return '$hours ${l10n.hours}';
  return '$hours ${l10n.hours} $minutes ${l10n.min}';
}
