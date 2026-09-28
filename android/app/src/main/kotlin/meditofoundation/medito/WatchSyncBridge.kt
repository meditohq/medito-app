package meditofoundation.medito

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Bridges the Wear OS app and Dart over `medito.app/watch` — the same channel
 * and methods as the iPhone's WatchSessionManager, so watch_sync_service.dart
 * drives both.
 *
 * Dart → watch: `updateContext` writes one DataItem at [CONTEXT_PATH], which
 * the Data Layer persists and syncs to the watch whenever it connects.
 *
 * Watch → Dart: each finished session arrives as a DataItem under
 * [SESSION_PREFIX], possibly while Flutter isn't running (see
 * [WatchDataListenerService]), so they are queued in SharedPreferences until
 * Dart drains them with `takePendingSessions` (nudged with
 * `sessionsAvailable` when the channel is live).
 */
object WatchSyncBridge {
    const val CONTEXT_PATH = "/medito/context"
    const val SESSION_PREFIX = "/medito/session/"
    private const val TAG = "WatchSync"
    private const val PREFS = "medito_watch_sync"
    private const val PENDING_KEY = "pending_sessions"
    private const val SEEN_KEY = "seen_sessions"

    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger, context: Context) {
        val appContext = context.applicationContext
        channel = MethodChannel(messenger, "medito.app/watch").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateContext" -> updateContext(appContext, call.arguments as? Map<*, *>, result)
                    "takePendingSessions" -> result.success(takePendingSessions(appContext))
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun updateContext(context: Context, payload: Map<*, *>?, result: MethodChannel.Result) {
        if (payload == null) return result.success(false)
        try {
            val request = PutDataMapRequest.create(CONTEXT_PATH).apply {
                dataMap.putString("json", JSONObject(payload).toString())
                dataMap.putLong("sentAt", (payload["sentAt"] as? Number)?.toLong() ?: System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()
            Wearable.getDataClient(context).putDataItem(request)
                .addOnSuccessListener { result.success(true) }
                .addOnFailureListener {
                    // No Play services / Wear API (e.g. no watch ever paired).
                    Log.w(TAG, "putDataItem failed: ${it.message}")
                    result.success(false)
                }
        } catch (e: Exception) {
            Log.w(TAG, "updateContext failed", e)
            result.success(false)
        }
    }

    private fun takePendingSessions(context: Context): List<Map<String, Any?>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pending = JSONArray(prefs.getString(PENDING_KEY, "[]"))
        prefs.edit().remove(PENDING_KEY).apply()
        return (0 until pending.length()).map { i ->
            val obj = pending.getJSONObject(i)
            obj.keys().asSequence().associateWith { obj.get(it) }
        }
    }

    /** Called from [WatchDataListenerService] for each finished session. */
    @Synchronized
    fun enqueue(context: Context, json: String) {
        val session = runCatching { JSONObject(json) }.getOrNull() ?: return
        if (session.optString("type") != "sessionCompleted") return

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        // Remember recent sessions so a redelivered item isn't recorded twice.
        val key = "${session.optString("trackId")}|${session.optLong("timestamp")}"
        val seen = JSONArray(prefs.getString(SEEN_KEY, "[]"))
        if ((0 until seen.length()).any { seen.getString(it) == key }) return
        seen.put(key)
        val trimmed = JSONArray((maxOf(0, seen.length() - 50) until seen.length()).map { seen.getString(it) })
        val pending = JSONArray(prefs.getString(PENDING_KEY, "[]")).put(session)
        prefs.edit()
            .putString(SEEN_KEY, trimmed.toString())
            .putString(PENDING_KEY, pending.toString())
            .apply()

        main.post { channel?.invokeMethod("sessionsAvailable", null) }
    }
}

/**
 * Receives sessions finished on the watch, even when the app isn't running,
 * queues them for Dart and deletes the delivered DataItem.
 */
class WatchDataListenerService : WearableListenerService() {
    override fun onDataChanged(dataEvents: DataEventBuffer) {
        val client = Wearable.getDataClient(this)
        dataEvents.filter {
            it.type == DataEvent.TYPE_CHANGED &&
                it.dataItem.uri.path?.startsWith(WatchSyncBridge.SESSION_PREFIX) == true
        }.forEach { event ->
            val item = event.dataItem
            DataMapItem.fromDataItem(item).dataMap.getString("json")?.let {
                WatchSyncBridge.enqueue(applicationContext, it)
            }
            client.deleteDataItems(Uri.parse(item.uri.toString()))
        }
    }
}
