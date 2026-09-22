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

}
