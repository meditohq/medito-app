package meditofoundation.medito.wear

import android.content.Context
import android.net.Uri
import android.util.Log
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONObject
import java.io.File

/**
 * Holds what the phone last sent (Continue, Daily, favourites, stat) and sends
 * finished sessions back so they count towards stats and the streak.
 *
 * Both directions use the Wearable Data Layer: the phone keeps one DataItem at
 * [CONTEXT_PATH] (persisted and synced to the watch whenever it connects, so
 * the list is there with the phone out of range or after a reinstall), and
 * each finished session is its own DataItem under [SESSION_PATH], which the
 * system delivers whenever the phone is next reachable.
 */
object WatchRepository {
    const val CONTEXT_PATH = "/medito/context"
    const val SESSION_PATH = "/medito/session"
    private const val TAG = "MeditoWatch"

    private val _state = MutableStateFlow(WatchState())
    val state: StateFlow<WatchState> = _state

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private lateinit var appContext: Context

    private val listener = DataClient.OnDataChangedListener { events ->
        events.filter { it.type == DataEvent.TYPE_CHANGED && it.dataItem.uri.path == CONTEXT_PATH }
            .lastOrNull()
            ?.let { apply(DataMapItem.fromDataItem(it.dataItem).dataMap.getString("json")) }
    }

    fun init(context: Context) {
        appContext = context.applicationContext
        Wearable.getDataClient(appContext).addListener(listener)
        refresh()
    }

    /** Reads the persisted context DataItem (from whichever phone node). */
    fun refresh() {
        scope.launch {
            val raw = runCatching {
                val items = Wearable.getDataClient(appContext)
                    .getDataItems(Uri.parse("wear://*$CONTEXT_PATH"))
                    .await()
                try {
                    items.map { DataMapItem.fromDataItem(it).dataMap }
                        .maxByOrNull { it.getLong("sentAt") }
                        ?.getString("json")
                } finally {
                    items.release()
                }
            }.onFailure { Log.w(TAG, "Couldn't read watch context", it) }.getOrNull()

            apply(raw ?: debugContext())
        }
    }

    private fun apply(raw: String?) {
        raw ?: return
        _state.value = WatchState.parse(raw)
    }

    /**
     * Debug builds only: with no paired phone (e.g. a lone emulator), read a
     * context pushed with
     * `adb shell run-as <pkg> sh -c 'cat > files/debug_context.json'`.
     */
    private fun debugContext(): String? {
        if (!BuildConfig.DEBUG) return null
        val file = File(appContext.filesDir, "debug_context.json")
        return if (file.exists()) file.readText() else null
    }

    /** Queues a completed session for the phone. */
    fun reportCompleted(
        trackId: String,
        fileId: String,
        guide: String,
        durationMs: Long,
        endedAt: Long = System.currentTimeMillis(),
    ) {
        val payload = JSONObject()
            .put("type", "sessionCompleted")
            .put("trackId", trackId)
            .put("fileId", fileId)
            .put("guide", guide)
            .put("duration", durationMs)
            .put("timestamp", endedAt)
        val request = PutDataMapRequest.create("$SESSION_PATH/$endedAt").apply {
            dataMap.putString("json", payload.toString())
        }.asPutDataRequest().setUrgent()

        scope.launch {
            runCatching { Wearable.getDataClient(appContext).putDataItem(request).await() }
                .onFailure { Log.w(TAG, "Couldn't queue finished session", it) }
        }
    }
}
