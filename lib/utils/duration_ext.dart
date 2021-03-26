extension DurationExtensions on Duration {
  /// Converts the duration into a readable string
  /// 15:35
  String toMinutesSeconds() {
    var twoDigitMinutes = _toTwoDigits(inMinutes
        .remainder(100)); //NB: if it's over 100 mins it'll show 0:00!!
    var twoDigitSeconds = _toTwoDigits(inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  String _toTwoDigits(int n) {
    if (n >= 10) return '$n';
    return '0$n';
  }
}