package com.meditofoundation.medito

import android.content.Context
import org.json.JSONObject

object SharedPreferencesManager {
    private const val PREFS_NAME = "MeditoAudioPrefs"
    private const val KEY_LAST_COMPLETED_TRACK = "lastCompletedTrack"

    fun saveCompletionData(context: Context, completionData: JSONObject) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LAST_COMPLETED_TRACK, completionData.toString())
            .apply()
    }

    fun getCompletionData(context: Context): String? {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_LAST_COMPLETED_TRACK, null)
    }

    fun clearCompletionData(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_LAST_COMPLETED_TRACK)
            .apply()
    }
}