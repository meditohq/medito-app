import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';

class BlackFridayUtils {
  static const int blackFridayDurationDays = 7;

  /// Debug builds only: `--dart-define=FORCE_BLACK_FRIDAY=true` shows the
  /// Black Friday Home layout on any day, to check how it looks.
  static const bool _force = bool.fromEnvironment('FORCE_BLACK_FRIDAY');

  /// The day after the fourth Thursday of November.
  static DateTime blackFriday(int year) {
    final firstOfNovember = DateTime(year, 11, 1);
    final firstThursday =
        1 + (DateTime.thursday - firstOfNovember.weekday + 7) % 7;
    return DateTime(year, 11, firstThursday + 21 + 1);
  }

  /// Thanksgiving through a week after Black Friday, so Cyber Monday is in.
  static bool isBlackFridayWeek(DateTime now) {
    if (_force) return true;
    final today = DateTime(now.year, now.month, now.day);
    final friday = blackFriday(now.year);
    final start = DateTime(friday.year, friday.month, friday.day - 1);
    final end = DateTime(
      friday.year,
      friday.month,
      friday.day + blackFridayDurationDays + 1,
    );
    return !today.isBefore(start) && today.isBefore(end);
  }

  /// Dismissal lasts for the year it was made in, so closing the row one
  /// Black Friday doesn't hide it every Black Friday after.
  static bool isBlackFridayDismissedSync(SharedPreferences prefs) {
    if (_force) return false;
    return prefs.getInt(SharedPreferenceConstants.blackFridayDismissedYear) ==
        DateTime.now().year;
  }

  static Future<void> dismissBlackFriday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      SharedPreferenceConstants.blackFridayDismissedYear,
      DateTime.now().year,
    );
  }

  static Future<void> resetBlackFridayDismissal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPreferenceConstants.blackFridayDismissedYear);
  }
}
