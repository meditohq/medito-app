package com.meditofoundation.medito

import CompletionData
import android.content.Context
import android.util.Log
import org.json.JSONException
import org.json.JSONObject

object SharedPreferencesManager {
    private const val PREFS_NAME = "MeditoAudioPrefs"
    private const val KEY_LAST_COMPLETED_TRACK = "lastCompletedTrack"
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
}