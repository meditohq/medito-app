package meditofoundation.medito

import meditofoundation.medito.pigeon.CompletionData
import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

object SharedPreferencesManager {
    private const val PREFS_NAME = "MeditoAudioPrefs"
    private const val KEY_LAST_COMPLETED_TRACK = "lastCompletedTrack"
    private const val KEY_PENDING_REPEATS = "pendingRepeatPlaythroughs"
    private const val TAG = "SharedPreferencesManager"

    fun saveCompletionData(context: Context, completionData: CompletionData): Boolean {
        return try {
            val jsonData = JSONObject().apply {
                put("trackId", completionData.trackId)
                put("duration", completionData.duration)
                put("fileId", completionData.fileId)
                put("guideId", completionData.guideId)
                put("timestamp", completionData.timestamp)
            }

            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_LAST_COMPLETED_TRACK, jsonData.toString())
                .apply()
            true
        } catch (e: JSONException) {
            Log.e(TAG, "Error saving completion data: ${e.message}")
            false
        }
    }

    fun getCompletionData(context: Context): CompletionData? {
        val completionString = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_LAST_COMPLETED_TRACK, null)

        return try {
            completionString?.let {
                val json = JSONObject(it)
                if (json.has("trackId") && json.has("duration") && json.has("fileId") && json.has("timestamp")) {
                    CompletionData(
                        trackId = json.getString("trackId"),
                        duration = json.getLong("duration"),
                        fileId = json.getString("fileId"),
                        guideId = json.optString("guideId", "None"),
                        timestamp = json.getLong("timestamp")
                    )
                } else {
                    Log.w(TAG, "Missing required fields in stored completion data")
                    null
                }
            }
        } catch (e: JSONException) {
            Log.e(TAG, "Error parsing completion data: ${e.message}")
            null
        }
    }

    fun clearCompletionData(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_LAST_COMPLETED_TRACK)
            .apply()
    }

    // Repeat play-throughs not yet acknowledged by Dart. A list (not a single
    // slot like the completion) because repeat forever can finish several
    // loops while the engine is unavailable. Keyed by timestamp.
    @Synchronized
    fun addPendingRepeat(context: Context, completionData: CompletionData) {
        val pending = readPendingRepeats(context)
        pending.put(JSONObject().apply {
            put("trackId", completionData.trackId)
            put("duration", completionData.duration)
            put("fileId", completionData.fileId)
            put("guideId", completionData.guideId)
            put("timestamp", completionData.timestamp)
        })
        writePendingRepeats(context, pending)
    }

    @Synchronized
    fun getPendingRepeats(context: Context): List<CompletionData> {
        val pending = readPendingRepeats(context)
        return (0 until pending.length()).mapNotNull { i ->
            try {
                val json = pending.getJSONObject(i)
                CompletionData(
                    trackId = json.getString("trackId"),
                    duration = json.getLong("duration"),
                    fileId = json.getString("fileId"),
                    guideId = json.optString("guideId", "None"),
                    timestamp = json.getLong("timestamp")
                )
            } catch (e: JSONException) {
                Log.e(TAG, "Error parsing pending repeat: ${e.message}")
                null
            }
        }
    }

    @Synchronized
    fun removePendingRepeat(context: Context, completionData: CompletionData) {
        val pending = readPendingRepeats(context)
        val remaining = JSONArray()
        for (i in 0 until pending.length()) {
            val json = pending.optJSONObject(i) ?: continue
            if (json.optLong("timestamp") != completionData.timestamp) remaining.put(json)
        }
        writePendingRepeats(context, remaining)
    }

    private fun readPendingRepeats(context: Context): JSONArray {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_PENDING_REPEATS, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (e: JSONException) {
            Log.e(TAG, "Error parsing pending repeats: ${e.message}")
            JSONArray()
        }
    }

    private fun writePendingRepeats(context: Context, pending: JSONArray) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING_REPEATS, pending.toString())
            .apply()
    }
}