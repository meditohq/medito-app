package meditofoundation.medito

import org.junit.Assert.*
import org.junit.Test

class SessionBellScheduleTest {
    @Test fun cuesFollowMediaTimeWithoutDuplicates() {
        val cues = SessionBellSchedule()
        assertFalse(cues.update(0, -1))
        assertTrue(cues.update(0, 600000))
        assertFalse(cues.update(0, 600000))
        assertTrue(cues.update(300000, 600000))
        assertFalse(cues.update(300000, 600000))
        assertFalse(cues.update(600000, 600000))
    }

    @Test fun seeksSkipMissedCuesAndRestartRearms() {
        val cues = SessionBellSchedule()
        assertFalse(cues.update(360000, 600000))
        cues.seek(240000, 600000)
        assertFalse(cues.update(240000, 600000))
        assertTrue(cues.update(300000, 600000))
        cues.seek(360000, 600000)
        assertFalse(cues.update(360000, 600000))
        cues.seek(0, 600000)
        assertTrue(cues.update(0, 600000))
        assertTrue(cues.update(300000, 600000))
    }

    @Test fun finalCueFinishesBeforeSessionAtDifferentSpeeds() {
        for (speed in listOf(0.5, 1.0, 2.0)) {
            val cues = SessionBellSchedule()
            cues.update(0, 600000, speed)
            cues.update(300000, 600000, speed)
            val cue = 600000 - (6000 * speed).toLong()
            assertFalse(cues.update(cue - 1, 600000, speed))
            assertTrue(cues.update(cue, 600000, speed))
            assertFalse(cues.update(cue + 1, 600000, speed))
            assertFalse(cues.update(600000, 600000, speed))
        }
    }

    @Test fun seekingPastFinalCueSkipsIt() {
        val cues = SessionBellSchedule()
        cues.seek(598000, 600000)
        assertFalse(cues.update(598000, 600000))
        cues.seek(590000, 600000)
        assertTrue(cues.update(594000, 600000))
    }


    @Test fun beginningAndEndOmitsMidpoint() {
        val cues = SessionBellSchedule("beginningEnd")
        assertTrue(cues.update(0, 600000))
        assertFalse(cues.update(300000, 600000))
        assertTrue(cues.update(594000, 600000))
        assertFalse(cues.update(595000, 600000))
    }


    @Test fun eachCombinationRingsOnlySelectedCues() {
        val patterns = mapOf(
            "none" to listOf(false, false, false),
            "beginning" to listOf(true, false, false),
            "middle" to listOf(false, true, false),
            "end" to listOf(false, false, true),
            "beginningMiddle" to listOf(true, true, false),
            "beginningEnd" to listOf(true, false, true),
            "middleEnd" to listOf(false, true, true),
            "beginningMiddleEnd" to listOf(true, true, true)
        )
        for ((pattern, selected) in patterns) {
            val cues = SessionBellSchedule(pattern)
            assertEquals(pattern, selected[0], cues.update(0, 600000))
            assertFalse(cues.update(60000, 600000))
            assertEquals(pattern, selected[1], cues.update(300000, 600000))
            assertFalse(cues.update(300000, 600000))
            assertEquals(pattern, selected[2], cues.update(594000, 600000))
            assertFalse(cues.update(595000, 600000))
        }
    }

    @Test fun middleOnlyRearmsWithoutOpeningBell() {
        val cues = SessionBellSchedule("middle")
        assertFalse(cues.update(0, 600000))
        cues.seek(360000, 600000)
        assertFalse(cues.update(360000, 600000))
        cues.seek(240000, 600000)
        assertTrue(cues.update(300000, 600000))
        cues.seek(0, 600000)
        assertFalse(cues.update(0, 600000))
        assertTrue(cues.update(300000, 600000))
        assertFalse(cues.update(594000, 600000))
    }

    @Test fun shortMiddleOnlyTimerStillRingsWithoutEndBell() {
        val cues = SessionBellSchedule("middle")
        assertFalse(cues.update(0, 10000))
        assertTrue(cues.update(5000, 10000))
        assertFalse(cues.update(6000, 10000))
    }
}
