package meditofoundation.medito.wear

import org.json.JSONObject
import kotlin.math.roundToInt

/**
 * One playable session, resolved on the phone (guide + duration already picked
 * from the user's preferences) so the watch only has to stream it.
 */
data class WatchTrack(
    val id: String,
    val title: String,
    val subtitle: String,
    val audioUrl: String,
    val fileId: String,
    val durationMs: Long,
    val guide: String,
    /** Set when this is a favourited pack's next session. */
    val packTitle: String,
) {
    val minutes: Int get() = maxOf(1, (durationMs / 60000.0).roundToInt())

    /** A pack's next session can also be favourited on its own. */
    val rowKey: String get() = if (packTitle.isEmpty()) id else "pack|$packTitle|$id"

    companion object {
        fun from(json: JSONObject?): WatchTrack? {
            json ?: return null
            val id = json.optString("id")
            val audioUrl = json.optString("audioUrl")
            if (id.isEmpty() || audioUrl.isEmpty()) return null
            return WatchTrack(
                id = id,
                title = json.optString("title"),
                subtitle = json.optString("subtitle"),
                audioUrl = audioUrl,
                fileId = json.optString("fileId"),
                durationMs = json.optLong("durationMs"),
                guide = json.optString("guide"),
                packTitle = json.optString("packTitle"),
            )
        }
    }
}

data class UpNext(
    val track: WatchTrack,
    val packTitle: String,
    /** Small resized pack cover (the phone hero's image). */
    val coverUrl: String,
    val completed: Int,
    val total: Int,
)

/** What the phone last sent. `synced` is false until anything has arrived. */
data class WatchState(
    val synced: Boolean = false,
    val upNext: UpNext? = null,
    val daily: WatchTrack? = null,
    val favorites: List<WatchTrack> = emptyList(),
    val streak: Int = 0,
    /** 0–100, the same number as the phone's Home stat pill. */
    val consistency: Int? = null,
    /** Same rule as the phone's Home pill (the phone decides). */
    val showStreak: Boolean = false,
) {
    companion object {
        /** Parses the context the phone pushes (see watch_sync_service.dart). */
        fun parse(raw: String?): WatchState {
            if (raw.isNullOrEmpty()) return WatchState()
            val json = runCatching { JSONObject(raw) }.getOrNull() ?: return WatchState()
            // Signed out on the phone: show nothing from that account.
            if (json.optBoolean("signedOut")) return WatchState()

            val upNext = json.optJSONObject("upNext")?.let { dict ->
                WatchTrack.from(dict)?.let {
                    UpNext(
                        track = it,
                        packTitle = dict.optString("packTitle"),
                        coverUrl = dict.optString("coverUrl"),
                        completed = dict.optInt("completed"),
                        total = dict.optInt("total"),
                    )
                }
            }
            val favorites = json.optJSONArray("favorites")?.let { array ->
                (0 until array.length()).mapNotNull { WatchTrack.from(array.optJSONObject(it)) }
            } ?: emptyList()

            return WatchState(
                synced = true,
                upNext = upNext,
                daily = WatchTrack.from(json.optJSONObject("daily")),
                favorites = favorites,
                streak = json.optInt("streak"),
                consistency = if (json.has("consistency")) json.optInt("consistency") else null,
                showStreak = json.optBoolean("showStreak"),
            )
        }
    }
}
