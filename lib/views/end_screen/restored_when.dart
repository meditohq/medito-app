import 'package:medito/utils/day_boundary.dart';

/// How a restored end screen refers to when its session finished.
enum RestoredWhen { lastNight, earlierToday, yesterday }

/// Evenings from this hour, and the small hours before [_nightEndHour], are
/// "night": a sleep session that ends at 00:15 was "last night" to someone
/// opening the app at 07:00, not "today".
const _nightStartHour = 18;
const _nightEndHour = 5;

/// [dayBoundary] is the user's day-boundary setting, so "today" and
/// "yesterday" agree with the streak number below the line.
RestoredWhen restoredWhen(
  DateTime completedAt,
  DateTime now, {
  Duration dayBoundary = Duration.zero,
}) {
  final isNight =
      completedAt.hour >= _nightStartHour || completedAt.hour < _nightEndHour;
  if (isNight) {
    // The evening the night belongs to: 00:15 belongs to the one before.
    final evening = DateTime(
      completedAt.year,
      completedAt.month,
      completedAt.day - (completedAt.hour < _nightEndHour ? 1 : 0),
    );
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    // Up at 02:00 after a 01:00 session: that was earlier today.
    final sameSmallHours =
        now.hour < _nightEndHour &&
        completedAt.year == now.year &&
        completedAt.month == now.month &&
        completedAt.day == now.day;
    if (evening == yesterday && !sameSmallHours) return RestoredWhen.lastNight;
  }
  return dayOf(completedAt, dayBoundary) == dayOf(now, dayBoundary)
      ? RestoredWhen.earlierToday
      : RestoredWhen.yesterday;
}
