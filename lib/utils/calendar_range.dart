/// Pure helpers for the meditation calendar's range-selection feature.
///
/// Extracted from the widget so the date math (which has to survive DST
/// transitions, leap days, year boundaries, and triple-long-press range
/// expansion) can be unit-tested directly.
library;

import 'package:medito/utils/day_boundary.dart';

/// Returns midnight in the local timezone for the given day.
///
/// Hand-constructing `DateTime(y, m, d)` rather than calling
/// `subtract`/`add` with `Duration(days: 1)` is critical: a `Duration`
/// adds an exact 24h, which lands at 01:00 on a spring-forward day. The
/// constructor variant always returns local midnight.
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Enumerates every calendar day in `[start, end]` inclusive, returning a
/// list of midnight-normalised `DateTime` values.
///
/// Both endpoints are normalised so callers don't have to. Returns an empty
/// list when `end < start` (we don't auto-swap here — `expandRange` is
/// responsible for keeping the range ordered).
List<DateTime> enumerateDays(DateTime start, DateTime end) {
  final out = <DateTime>[];
  var cursor = startOfDay(start);
  final last = startOfDay(end);
  if (cursor.isAfter(last)) return out;
  while (!cursor.isAfter(last)) {
    out.add(cursor);
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  return out;
}

/// Recomputes the current streak from a set of activity dates.
///
/// Mirrors the walk in `StatsManager.calculateStreak` so the UI can preview
/// the post-add streak before any state is mutated.
///
/// `activityDates` may contain any `DateTime` values; only the date portion
/// (year/month/day) is consulted, so callers can pass either pre-normalised
/// midnights or raw timestamps interchangeably.
int projectStreak(
  Iterable<DateTime> activityDates,
  DateTime today, {
  Duration dayBoundaryOffset = Duration.zero,
}) {
  if (activityDates.isEmpty) return 0;

  // Normalise into a set of date-only entries. Done here so callers are
  // free to mix timestamps and midnights.
  final normalised = <DateTime>{};
  final todayStart = dayOf(today, dayBoundaryOffset);
  for (final d in activityDates) {
    final s = dayOf(d, dayBoundaryOffset);
    if (s.isAfter(todayStart)) continue; // future activity is ignored
    normalised.add(s);
  }
  if (normalised.isEmpty) return 0;

  final yesterday = DateTime(
    todayStart.year,
    todayStart.month,
    todayStart.day - 1,
  );
  final hasToday = normalised.contains(todayStart);
  final hasYesterday = normalised.contains(yesterday);
  if (!hasToday && !hasYesterday) return 0;

  var streak = hasToday ? 1 : 0;
  var cursor = yesterday;
  while (normalised.contains(cursor)) {
    streak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}

/// Result of a long-press, expressed as (start, end). Either may be null.
class RangeBounds {
  final DateTime? start;
  final DateTime? end;
  const RangeBounds(this.start, this.end);

  bool get isComplete => start != null && end != null;
  bool get isEmpty => start == null && end == null;
}

/// Computes the next range bounds after a long-press on [pressed].
///
/// Behaviour:
///   - No anchor yet → set anchor.
///   - Anchor only:
///       - same day → no-op (don't create a zero-length range).
///       - any other day → complete the range, ordered chronologically.
///   - Complete range:
///       - press inside the range → no-op (we never shrink).
///       - press outside the range → extend the matching endpoint.
RangeBounds expandRange(RangeBounds current, DateTime pressed) {
  final day = startOfDay(pressed);

  if (current.start == null) {
    return RangeBounds(day, null);
  }

  if (current.end == null) {
    if (day.isAtSameMomentAs(current.start!)) {
      return current;
    }
    if (day.isBefore(current.start!)) {
      return RangeBounds(day, current.start);
    }
    return RangeBounds(current.start, day);
  }

  // Complete range. Extend, but never shrink.
  if (day.isBefore(current.start!)) {
    return RangeBounds(day, current.end);
  }
  if (day.isAfter(current.end!)) {
    return RangeBounds(current.start, day);
  }
  return current;
}
