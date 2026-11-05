package meditofoundation.medito

/**
 * Cue state uses media time. A seek consumes skipped cues, zero restarts.
 *
 * The pattern string is either a bare name ("beginning", "beginningMiddleEnd",
 * …) or that name suffixed with "+N" where N is the interval in seconds; the
 * schedule then also rings every N seconds on top of the pattern cues.
 */
internal class SessionBellSchedule(pattern: String = "beginningMiddleEnd") {
    var pattern: String = pattern
        set(value) {
            field = value
            baseName = value.substringBefore('+')
            intervalSeconds = value.substringAfter('+', "").toIntOrNull() ?: 0
        }

    private var baseName: String = pattern.substringBefore('+')
    private var intervalSeconds: Int = pattern.substringAfter('+', "").toIntOrNull() ?: 0

    private val hasBeginning get() = baseName in setOf("beginning", "beginningMiddle", "beginningEnd", "beginningMiddleEnd", "everyMinute")
    private val hasMiddle get() = baseName in setOf("middle", "beginningMiddle", "middleEnd", "beginningMiddleEnd", "everyMinute")
    private val hasEnd get() = baseName in setOf("end", "beginningEnd", "middleEnd", "beginningMiddleEnd", "everyMinute")
    private var started = false
    private var middle = false
    private var end = false
    private var intervalTicksFired = 0

    private fun endPosition(duration: Long, speed: Double): Long =
        maxOf(duration / 2, duration - (6000 * speed).toLong())

    fun reset() { started = false; middle = false; end = false; intervalTicksFired = 0 }

    fun seek(position: Long, duration: Long, speed: Double = 1.0) {
        if (position == 0L) reset() else {
            started = true
            middle = duration > 0 && position >= duration / 2
            end = duration > 0 && position >= endPosition(duration, speed)
            if (intervalSeconds > 0) {
                intervalTicksFired = (position / 1000L / intervalSeconds).toInt()
            }
        }
    }

    fun update(position: Long, duration: Long, speed: Double = 1.0): Boolean {
        if (duration <= 0 || position >= duration) return false
        if (!started) {
            started = true
            middle = position >= duration / 2
            end = position >= endPosition(duration, speed)
            if (intervalSeconds > 0) {
                intervalTicksFired = (position / 1000L / intervalSeconds).toInt()
            }
            return hasBeginning && position < 2000
        }
        if (!end && position >= endPosition(duration, speed)) {
            end = true
            if (hasEnd) {
                middle = true
                return true
            }
        }
        if (hasMiddle && !middle && position >= duration / 2 && position < duration) {
            middle = true
            return true
        }
        if (intervalSeconds > 0) {
            val ticks = (position / 1000L / intervalSeconds).toInt()
            // Skip tick 0 — the beginning cue covers it.
            if (ticks > intervalTicksFired && ticks > 0) {
                intervalTicksFired = ticks
                return true
            }
        }
        return false
    }
}
