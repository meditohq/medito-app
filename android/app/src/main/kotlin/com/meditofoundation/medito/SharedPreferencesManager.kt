package com.meditofoundation.medito

import CompletionData
import android.content.Context
import org.json.JSONObject

object SharedPreferencesManager {
    private const val PREFS_NAME = "MeditoAudioPrefs"
    private const val KEY_LAST_COMPLETED_TRACK = "lastCompletedTrack"

    fun saveCompletionData(context: Context, completionData: CompletionData) {

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
    }

    fun getCompletionData(context: Context): CompletionData? {
        val completionString = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_LAST_COMPLETED_TRACK, null)

        return completionString?.let {
            val json = JSONObject(it)
            CompletionData(
                trackId = json.getString("trackId"),
                duration = json.getLong("duration"),
                fileId = json.getString("fileId"),
                guideId = json.optString("guideId"),
                timestamp = json.getLong("timestamp"),
            )
        }
    }

    fun clearCompletionData(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_LAST_COMPLETED_TRACK)
            .apply()
    }
}