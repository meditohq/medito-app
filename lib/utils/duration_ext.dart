import 'package:Medito/utils/utils.dart';

extension DurationExtensions on Duration {
  /// Converts the duration into a readable string
  /// 05:35 -> 05 min 35 sec
  String toMinutesSeconds() {
    var twoDigitMinutes = _toTwoDigits(
        inMinutes.remainder(100)); //NB: if it's over 100 mins it'll show 0:00!!
    var twoDigitSeconds = _toTwoDigits(inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  String toReadable() {
    var twoDigitMinutes = _toTwoDigits(
        inMinutes.remainder(100)); //NB: if it's over 100 mins it'll show 0:00!!
    var twoDigitSeconds = _toTwoDigits(inSeconds.remainder(60));

    if (twoDigitSeconds.isNotEmptyAndNotNull() && twoDigitMinutes != '00') {
      return '$twoDigitMinutes min $twoDigitSeconds sec';
    }
    return '$twoDigitSeconds sec';
  }

  String _toTwoDigits(int n) {
    if (n >= 10) return '$n';
    return '0$n';
  }
}

String formatSessionLength(String item) {
  if (item.contains(':')) {
    var duration = clockTimeToDuration(item);
    var time = '';
    if (duration.inMinutes < 1) {
      time = '<1';
    } else {
      time = duration.inMinutes.toString();
    }
    return '$time min';
  }
  return item + ' min';
}

Duration clockTimeToDuration(String lengthText) {
  //formats 00:00:00
  var tempList = lengthText.split(':');
  var tempListInts = tempList.map(int.parse).toList();

  if (tempListInts.length == 2) {
    return Duration(minutes: tempListInts[0], seconds: tempListInts[1]);
  }

  return Duration(
      hours: tempListInts[0],
      minutes: tempListInts[1],
      seconds: tempListInts[2]);
}