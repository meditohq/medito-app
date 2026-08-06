package meditofoundation.medito.widget

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File
import java.time.Instant
import java.time.ZoneOffset

/**
 * Runs the shared fixture in test/fixtures/streak_score_fixtures.json against
 * [StreakCalculator] (the on-device widget port). The same fixture is consumed
 * by the Dart test (test/stats_manager/streak_parity_test.dart) that exercises
 * the real source of truth, lib/utils/stats_manager.dart's calculateStreak —
 * keeping both suites pointed at one fixture file means drift between the two
 * implementations shows up as a CI failure instead of relying on the
 * sync-reminder comments alone.
 */
class StreakCalculatorParityTest {

    // Fixed to avoid any host-timezone dependence on day-boundary math.
    private val zone = ZoneOffset.UTC

    @Test
    fun `fixture cases match the Kotlin port`() {
        val fixtureFile = File("../../test/fixtures/streak_score_fixtures.json")
        check(fixtureFile.exists()) { "Fixture not found at ${fixtureFile.absolutePath}" }

        val fixture = JSONObject(fixtureFile.readText())
        val referenceInstant = Instant.parse(fixture.getString("referenceInstant"))
        val cases = fixture.getJSONArray("cases")

        fun atHourOffset(offsetHours: Double) =
            referenceInstant.plusMillis((offsetHours * 3_600_000L).toLong())

        for (i in 0 until cases.length()) {
            val testCase = cases.getJSONObject(i)
            val name = testCase.getString("name")
            val nowOffsetHours = testCase.getDouble("nowOffsetHours")
            val meditationOffsets = testCase.getJSONArray("meditationOffsetHours")
            val freezeOffsets = testCase.getJSONArray("freezeOffsetHours")
            val dayBoundaryOffsetHours = testCase.getInt("dayBoundaryOffsetHours")
            val expectedStreak = testCase.getInt("expectedStreak")

            val nowInstant = atHourOffset(nowOffsetHours)
            val meditationTimestamps = (0 until meditationOffsets.length())
                .map { atHourOffset(meditationOffsets.getDouble(it)).toEpochMilli() }
            val freezeTimestamps = (0 until freezeOffsets.length())
                .map { atHourOffset(freezeOffsets.getDouble(it)).toEpochMilli() }

            val actualStreak = StreakCalculator.calculate(
                meditationTimestamps,
                freezeTimestamps,
                dayBoundaryOffsetHours,
                nowMillis = nowInstant.toEpochMilli(),
                zone = zone,
            )

            assertEquals("fixture case \"$name\"", expectedStreak, actualStreak)
        }
    }
}
