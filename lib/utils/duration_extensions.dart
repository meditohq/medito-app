import 'package:medito/utils/utils.dart';

extension DurationExtensions on Duration {
  /// A player clock: `05:35`, or `1:05:35` from an hour up. Minutes used to
  /// wrap at 100 (4 h 28 m read `68:00`), which only showed once timers
  /// allowed sessions over 100 minutes.
  String toMinutesSeconds() {
    final twoDigitSeconds = _toTwoDigits(inSeconds.remainder(60));
    if (inHours > 0) {
      return '$inHours:${_toTwoDigits(inMinutes.remainder(60))}:$twoDigitSeconds';
    }
    return '${_toTwoDigits(inMinutes)}:$twoDigitSeconds';
  }

  String toReadable() {
    var twoDigitMinutes = _toTwoDigits(inMinutes);
    var twoDigitSeconds = _toTwoDigits(inSeconds.remainder(60));

    if (twoDigitSeconds.isNotNullAndNotEmpty() && twoDigitMinutes != '00') {
      return '$twoDigitMinutes min $twoDigitSeconds sec';
    }

    return '$twoDigitSeconds sec';
  }

  String _toTwoDigits(int n) {
    if (n >= 10) return '$n';

    return '0$n';
  }
}

String formatTrackLength(String? item) {
  if (item != null && item.contains(':')) {
    var duration = clockTimeToDuration(item);
    var time = '';
    if (duration.inMinutes < 1) {
      time = '<1';
    } else {
      var min = duration.inMinutes;
      if (duration.inSeconds % 60 > 30) {
        // round up
        min++;
      }
      time = min.toString();
    }

    return '$time min';
  }
  if (item == null) return '';

  return '$item min';
}

Duration clockTimeToDuration(String? lengthText) {
  if (lengthText == null) return const Duration();

  //formats 00:00:00
  var tempList = lengthText.split(':');
  var tempListInts = tempList.map(int.parse).toList();

  if (tempListInts.length == 2) {
    return Duration(minutes: tempListInts[0], seconds: tempListInts[1]);
  }

  return Duration(
    hours: tempListInts[0],
    minutes: tempListInts[1],
    seconds: tempListInts[2],
  );
}
