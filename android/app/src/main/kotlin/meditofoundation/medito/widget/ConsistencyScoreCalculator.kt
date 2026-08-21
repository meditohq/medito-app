package meditofoundation.medito.widget

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

// Ported from `calculateConsistencyScore` in lib/utils/stats_manager.dart so the
// widget can recompute the percentage on-device from raw activity dates instead
// of trusting the last value Dart happened to push.
// ⚠️ KEEP IN SYNC: if the algorithm in stats_manager.dart ever changes, update
// this copy too (and vice versa) — there is no shared source of truth. Both
// implementations are checked against the same fixture list in
// test/fixtures/consistency_score_fixtures.json (Dart test:
// test/stats_manager/consistency_score_parity_test.dart, Kotlin test:
// ConsistencyScoreCalculatorParityTest.kt) — update the fixtures alongside any
// algorithm change and confirm both suites still pass.
object ConsistencyScoreCalculator {
    fun calculate(
        meditationDates: List<Long>,
        freezeDates: List<Long>,
        today: LocalDate = LocalDate.now(ZoneId.systemDefault()),
        zone: ZoneId = ZoneId.systemDefault(),
        dayBoundaryOffsetHours: Int = 0,
    ): Int {
        // Mirrors Dart's `dayOf` / StreakCalculator: shift the instant back by
        // the day-boundary offset before taking the local date, so this score
        // buckets days identically to the streak. Callers must pass an
        // offset-adjusted `today` (see ConsistencyWidget).
        fun toLocalDate(millis: Long) =
            Instant.ofEpochMilli(millis)
                .minusSeconds(dayBoundaryOffsetHours * 3600L)
                .atZone(zone)
                .toLocalDate()

        val audioDates = meditationDates
            .map(::toLocalDate)
            .filter { !it.isAfter(today) }
            .toSet()

        val freezeOnlyDates = freezeDates
            .map(::toLocalDate)
            .filter { !it.isAfter(today) && it !in audioDates }
            .toSet()

        val allActivityDates = (audioDates + freezeOnlyDates).sorted()
        if (allActivityDates.isEmpty()) return 0

        val firstSessionDate = allActivityDates.first()
        val daysSinceFirstSession = ChronoUnit.DAYS.between(firstSessionDate, today) + 1

        if (daysSinceFirstSession == 1L) {
            return if (allActivityDates.contains(today)) 100 else 0
        }

        // Bootstrap phase: simple ratio for the first 30 days
        if (daysSinceFirstSession < 30) {
            val ratio = allActivityDates.size.toDouble() / daysSinceFirstSession
            return (ratio.coerceIn(0.0, 1.0) * 100).let { Math.round(it).toInt() }
        }

        // EMA phase: replay history day by day starting from day 30,
        // seeding with the ratio at day 29.
        val alpha = 0.1
        val gracePenalty = 0.5 // value used for a single isolated missed day

        val day29 = firstSessionDate.plusDays(28)
        val activeDaysAtDay29 = allActivityDates.count { !it.isAfter(day29) }
        var ema = activeDaysAtDay29 / 29.0

        val activitySet = allActivityDates.toHashSet()
        var currentDay = firstSessionDate.plusDays(29)
        while (!currentDay.isAfter(today)) {
            val hadActivity = activitySet.contains(currentDay)

            val dayValue = if (hadActivity) {
                1.0
            } else {
                val prevDay = currentDay.minusDays(1)
                val nextDay = currentDay.plusDays(1)
                val prevActive = activitySet.contains(prevDay)
                val nextActive = if (nextDay.isAfter(today)) false else activitySet.contains(nextDay)
                // Single isolated miss gets half penalty; consecutive misses get full penalty
                if (prevActive || nextActive) gracePenalty else 0.0
            }

            ema = alpha * dayValue + (1 - alpha) * ema
            currentDay = currentDay.plusDays(1)
        }

        return (ema.coerceIn(0.0, 1.0) * 100).let { Math.round(it).toInt() }
    }
}
