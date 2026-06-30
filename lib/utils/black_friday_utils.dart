import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';

class BlackFridayUtils {
  static const int blackFridayStartDay = 28;
  static const int blackFridayMonth = 11;
  static const int blackFridayDurationDays = 7;

  static bool isBlackFridayWeek(DateTime now) {
    final currentYear = now.year;
    final blackFridayStart = DateTime(
      currentYear,
      blackFridayMonth,
      blackFridayStartDay,
    );
    final blackFridayEnd = blackFridayStart.add(
      Duration(days: blackFridayDurationDays),
    );

    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(
      blackFridayStart.year,
      blackFridayStart.month,
      blackFridayStart.day,
    );
    final endDate = DateTime(
      blackFridayEnd.year,
      blackFridayEnd.month,
      blackFridayEnd.day,
    );

    final effectiveStartDate = startDate.subtract(const Duration(days: 1));
    final effectiveEndDate = endDate.add(const Duration(days: 1));

    return !today.isBefore(effectiveStartDate) &&
        today.isBefore(effectiveEndDate);
  }

  static bool isBlackFridayDismissedSync(SharedPreferences prefs) {
    return prefs.getBool(SharedPreferenceConstants.blackFridayDismissed) ??
        false;
  }

  static Future<void> dismissBlackFriday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SharedPreferenceConstants.blackFridayDismissed, true);
  }

  static Future<void> resetBlackFridayDismissal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPreferenceConstants.blackFridayDismissed);
  }
}
