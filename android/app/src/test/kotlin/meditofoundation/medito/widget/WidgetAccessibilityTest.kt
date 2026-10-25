package meditofoundation.medito.widget

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

/** The single descriptions TalkBack reads for the home-screen widgets. */
class WidgetAccessibilityTest {

    private val strings = WidgetStrings()
    private val today = LocalDate.of(2026, 10, 25)

    @Test
    fun `stat summary names the stat, today and the shown days`() {
        val days = setOf(today, today.minusDays(1), today.minusDays(3), today.minusDays(9))
        assertEquals(
            "Meditation streak: 2 days. Meditated today. Meditated on 3 of the last 5 days",
            statAccessibilitySummary(
                strings.streakSummary.fill("value" to "2 days"), today, days, 5, strings,
            ),
        )
        assertEquals(
            "Consistency score: 40%. Not meditated yet today. Meditated on 3 of the last 28 days",
            statAccessibilitySummary(
                strings.consistencySummary.fill("value" to "40%"),
                today,
                days - today,
                28,
                strings,
            ),
        )
    }

    @Test
    fun `stat summary uses the pushed templates`() {
        val german = WidgetStrings(
            consistencySummary = "Beständigkeitswert: {value}",
            notDoneToday = "Heute noch nicht meditiert",
            recentDays = "An {done} der letzten {total} Tage meditiert",
        )
        assertEquals(
            "Beständigkeitswert: 0%. Heute noch nicht meditiert. An 0 der letzten 35 Tage meditiert",
            statAccessibilitySummary(
                german.consistencySummary.fill("value" to "0%"), today, emptySet(), 35, german,
            ),
        )
    }

    @Test
    fun `up next summary mirrors the Home hero`() {
        assertEquals(
            "Continue: Basics — Breath awareness, 2 of 10",
            upNextAccessibilitySummary("Breath awareness", "Basics", 2, 10, strings),
        )
        assertEquals(
            "Start here: Breath awareness, 0 of 10",
            upNextAccessibilitySummary("Breath awareness", "", 0, 10, strings),
        )
    }

    @Test
    fun `up next summary for a finished pack and a fresh install`() {
        assertEquals(
            "Pack complete. Choose what's next",
            upNextAccessibilitySummary("", "", 10, 10, strings),
        )
        assertEquals("Choose what's next", upNextAccessibilitySummary("", "", 0, 0, strings))
    }
}
