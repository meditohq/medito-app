package meditofoundation.medito.wear

import org.json.JSONObject
import org.json.JSONArray
import java.io.ByteArrayOutputStream
import java.util.Base64
import java.util.zip.GZIPInputStream
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/** Authoritative phone snapshot + unacknowledged local sessions. */
object WatchProgress {
    fun recordedKeys(snapshot: JSONObject): Set<String> = runCatching {
        val array = snapshot.optJSONArray("recordedSessions") ?: run {
            val bytes = Base64.getDecoder().decode(snapshot.optString("recordedSessionsGzip"))
            GZIPInputStream(bytes.inputStream()).use { stream ->
                // Match the Swift bound and avoid unbounded allocations on corrupt data.
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(4096)
                while (true) {
                    val count = stream.read(buffer)
                    if (count < 0) break
                    check(output.size() + count <= 16 * 1024 * 1024)
                    output.write(buffer, 0, count)
                }
                JSONArray(output.toString("UTF-8"))
            }
        }
        (0 until array.length()).map { array.getString(it) }.toSet()
    }.getOrDefault(emptySet())

    fun deliveryKey(entry: JSONObject) = "${entry.optString("trackId")}|${entry.optLong("timestamp")}"

    fun recordedTimestamp(entry: JSONObject, zone: ZoneId = ZoneId.systemDefault()): Long {
        if (entry.has("statsTimestamp")) return entry.getLong("statsTimestamp")
        val end = entry.optLong("timestamp")
        val start = end - entry.optLong("duration")
        fun day(ms: Long) = Instant.ofEpochMilli(ms).atZone(zone).toLocalDate()
        return if (day(start).isBefore(day(end))) start else end
    }

    fun recordKey(entry: JSONObject) = "${entry.optString("trackId")}|${recordedTimestamp(entry)}"

    fun project(snapshot: JSONObject, pending: List<JSONObject>, now: Long = System.currentTimeMillis()): JSONObject {
        val result = JSONObject(snapshot.toString())
        if (snapshot.optBoolean("signedOut")) return result
        val recorded = recordedKeys(snapshot)
        val outstanding = pending.filter { recordKey(it) !in recorded }
        result.optJSONObject("upNext")?.let { pack ->
            pack.optJSONArray("packTrackIds")?.let { a ->
                val ids = (0 until a.length()).map { a.getString(it) }.toSet()
                val completed = pack.optJSONArray("completedTrackIds")?.let { c ->
                    (0 until c.length()).map { c.getString(it) }.toMutableSet()
                } ?: mutableSetOf()
                outstanding.map { it.optString("trackId") }.filter { it in ids }.forEach { completed.add(it) }
                pack.put("completed", completed.size)
                val remaining = pack.optJSONArray("remainingTracks")
                val next = remaining?.let { tracks ->
                    (0 until tracks.length()).map { tracks.getJSONObject(it) }
                        .firstOrNull { it.optString("id") !in completed }
                }
                pack.put("canPlay", next != null)
                next?.keys()?.forEach { pack.put(it, next.get(it)) }
            }
        }
        activityTimestamps(snapshot, recorded)?.let { timestamps ->
            val offset = snapshot.optLong("dayBoundaryOffsetMs")
            val zone = ZoneId.systemDefault()
            fun day(ms: Long): LocalDate = Instant.ofEpochMilli(ms - offset).atZone(zone).toLocalDate()
            val today = day(now)
            val meditation = timestamps + outstanding.map { recordedTimestamp(it) }
            val days = meditation
                .map(::day).filter { !it.isAfter(today) }.toSet()
            var streak = if (today in days) 1 else 0
            var check = today.minusDays(1)
            while (check in days) { streak++; check = check.minusDays(1) }
            result.put("streak", streak)
            if (snapshot.has("consistency")) {
                val freezes = snapshot.optJSONArray("freezeTimestamps") ?: JSONArray()
                result.put("consistency", consistencyPercent(
                    meditation,
                    (0 until freezes.length()).map { freezes.getLong(it) },
                    today,
                    offset,
                    zone
                ))
            }
        }
        return result
    }

    private fun activityTimestamps(snapshot: JSONObject, recorded: Set<String>): List<Long>? {
        snapshot.optJSONArray("activityTimestamps")?.let { timestamps ->
            return (0 until timestamps.length()).map { timestamps.getLong(it) }
        }
        if (!snapshot.has("recordedSessions") && !snapshot.has("recordedSessionsGzip")) return null
        return recorded.mapNotNull { it.substringAfterLast("|").toLongOrNull() }
    }

    private fun consistencyPercent(
        meditationTimestamps: List<Long>,
        freezeTimestamps: List<Long>,
        today: LocalDate,
        offset: Long,
        zone: ZoneId,
    ): Int {
        fun day(ms: Long): LocalDate = Instant.ofEpochMilli(ms - offset).atZone(zone).toLocalDate()
        val audioDays = meditationTimestamps.map(::day)
            .filter { !it.isAfter(today) }
            .toSet()
        val freezeDays = freezeTimestamps.map(::day)
            .filter { !it.isAfter(today) && it !in audioDays }
            .toSet()
        val activityDays = (audioDays + freezeDays).sorted()
        if (activityDays.isEmpty()) return 0

        val first = activityDays.first()
        val daysSinceFirst = ChronoUnit.DAYS.between(first, today) + 1
        if (daysSinceFirst == 1L) return if (today in activityDays) 100 else 0
        if (daysSinceFirst < 30) {
            return Math.round((activityDays.size.toDouble() / daysSinceFirst).coerceIn(0.0, 1.0) * 100).toInt()
        }

        val alpha = 0.1
        val gracePenalty = 0.5
        val day29 = first.plusDays(28)
        val activeAtDay29 = activityDays.count { !it.isAfter(day29) }
        var ema = activeAtDay29 / 29.0
        val activitySet = activityDays.toSet()
        var current = first.plusDays(29)
        while (!current.isAfter(today)) {
            val dayValue = if (current in activitySet) {
                1.0
            } else {
                val previous = current.minusDays(1)
                val next = current.plusDays(1)
                val nextActive = if (next.isAfter(today)) false else next in activitySet
                if (previous in activitySet || nextActive) gracePenalty else 0.0
            }
            ema = alpha * dayValue + (1 - alpha) * ema
            current = current.plusDays(1)
        }
        return Math.round(ema.coerceIn(0.0, 1.0) * 100).toInt()
    }
}
