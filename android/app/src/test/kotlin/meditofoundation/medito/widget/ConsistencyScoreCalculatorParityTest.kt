package meditofoundation.medito.widget

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset

/**
 * Runs the shared fixture in test/fixtures/consistency_score_fixtures.json against
 * [ConsistencyScoreCalculator] (the on-device widget port). The same fixture is
 * consumed by the Dart test (test/stats_manager/consistency_score_parity_test.dart)
 * that exercises the real source of truth,
 * lib/utils/stats_manager.dart's calculateConsistencyScore — keeping both suites
 * pointed at one fixture file means drift between the two implementations shows
 * up as a CI failure instead of relying on the sync-reminder comments alone.
 */
class ConsistencyScoreCalculatorParityTest {

    // Fixed to avoid any host-timezone dependence on day-boundary math.
    private val zone: ZoneId = ZoneOffset.UTC

    @Test
    fun `fixture cases match the Kotlin port`() {
        val fixtureFile = File("../../test/fixtures/consistency_score_fixtures.json")
        check(fixtureFile.exists()) { "Fixture not found at ${fixtureFile.absolutePath}" }

        val fixture = JSONObject(fixtureFile.readText())
        val referenceDate = LocalDate.parse(fixture.getString("referenceDate"))
        val cases = fixture.getJSONArray("cases")

        for (i in 0 until cases.length()) {
            val testCase = cases.getJSONObject(i)
            val name = testCase.getString("name")
            val audioOffsets = testCase.getJSONArray("audioOffsetDays")
            val freezeOffsets = testCase.getJSONArray("freezeOffsetDays")
            val expectedPercent = testCase.getInt("expectedPercent")

            fun toEpochMillis(offsetDays: Int) =
                referenceDate.plusDays(offsetDays.toLong())
                    .atStartOfDay(zone)
                    .toInstant()
                    .toEpochMilli()

            val meditationDates = (0 until audioOffsets.length())
                .map { toEpochMillis(audioOffsets.getInt(it)) }
            val freezeDates = (0 until freezeOffsets.length())
                .map { toEpochMillis(freezeOffsets.getInt(it)) }

            val actualPercent = ConsistencyScoreCalculator.calculate(
                meditationDates,
                freezeDates,
                today = referenceDate,
                zone = zone,
            )

            assertEquals("fixture case \"$name\"", expectedPercent, actualPercent)
        }
    }
}
