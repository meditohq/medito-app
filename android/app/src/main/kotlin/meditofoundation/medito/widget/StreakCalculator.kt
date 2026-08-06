package meditofoundation.medito.widget

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

// Ported from `calculateStreak` in lib/utils/stats_manager.dart so the widget
// can recompute the current streak on-device from raw activity timestamps
// instead of trusting the last value Dart happened to push.
// ⚠️ KEEP IN SYNC: if the algorithm in stats_manager.dart ever changes, update
// this copy too (and vice versa) — there is no shared source of truth. Both
// implementations are checked against the same fixture list in
// test/fixtures/streak_score_fixtures.json (Dart test:
// test/stats_manager/streak_parity_test.dart, Kotlin test:
// StreakCalculatorParityTest.kt) — update the fixtures alongside any
// algorithm change and confirm both suites still pass.
object StreakCalculator {
    fun calculate(
        meditationTimestamps: List<Long>,
        freezeTimestamps: List<Long>,
        dayBoundaryOffsetHours: Int = 0,
        nowMillis: Long = System.currentTimeMillis(),
        zone: ZoneId = ZoneId.systemDefault(),
    ): Int {
        // Mirrors Dart's `dayOf`: shift the instant back by the offset, then
        // take the calendar day of the shifted instant. Note "today" itself is
        // derived this way too (Dart: `today = dayOf(now, offset)`) — with a
        // non-zero offset, "today" doesn't roll over at local midnight either.
        fun dayOf(millis: Long): LocalDate =
            Instant.ofEpochMilli(millis)
                .minusSeconds(dayBoundaryOffsetHours * 3600L)
                .atZone(zone)
                .toLocalDate()

        val today = dayOf(nowMillis)
        val activityDates = HashSet<LocalDate>()

        for (ts in meditationTimestamps) {
            val day = dayOf(ts)
            if (!day.isAfter(today)) activityDates.add(day)
        }
        for (ts in freezeTimestamps) {
            val day = dayOf(ts)
            if (!day.isAfter(today)) activityDates.add(day)
        }

        if (activityDates.isEmpty()) return 0

        val yesterday = today.minusDays(1)
        val hasActivityToday = activityDates.contains(today)
        val hasActivityYesterday = activityDates.contains(yesterday)

        if (!hasActivityToday && !hasActivityYesterday) return 0

        var streak = if (hasActivityToday) 1 else 0
        var checkDate = yesterday
        while (activityDates.contains(checkDate)) {
            streak++
            checkDate = checkDate.minusDays(1)
        }

        return streak
    }
}
