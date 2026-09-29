package meditofoundation.medito

/** Cue state uses media time. A seek consumes skipped cues, zero restarts. */
internal class SessionBellSchedule {
    private var started = false
    private var middle = false
    private var end = false

    private fun endPosition(duration: Long, speed: Double): Long =
        maxOf(duration / 2, duration - (6000 * speed).toLong())

    fun reset() { started = false; middle = false; end = false }

    fun seek(position: Long, duration: Long, speed: Double = 1.0) {
        if (position == 0L) reset() else {
            started = true
            middle = duration > 0 && position >= duration / 2
            end = duration > 0 && position >= endPosition(duration, speed)
        }
    }

    fun update(position: Long, duration: Long, speed: Double = 1.0): Boolean {
        if (duration <= 0 || position >= duration) return false
        if (!started) {
            started = true
            middle = position >= duration / 2
            end = position >= endPosition(duration, speed)
            return position < 2000
        }
        if (!end && position >= endPosition(duration, speed)) {
            end = true
            middle = true
            return true
        }
        if (!middle && position >= duration / 2 && position < duration) {
            middle = true
            return true
        }
        return false
    }
}
