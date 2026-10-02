package meditofoundation.medito.wear

import android.content.Context
import android.net.Uri
import com.google.android.gms.wearable.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.UUID

/** Assets are copied to app storage before acknowledging offline readiness. */
object WatchDownloads {
    const val DOWNLOAD = "/medito/download/"
    const val STATUS = "/medito/download-status/"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mutex = Mutex()
    private val _tracks = MutableStateFlow<List<WatchTrack>>(emptyList())
    val tracks: StateFlow<List<WatchTrack>> = _tracks
    // Sent from the phone but still copying; shown so Downloads isn't empty
    // while a long session transfers.
    private val _incoming = MutableStateFlow<List<WatchTrack>>(emptyList())
    val incoming: StateFlow<List<WatchTrack>> = _incoming
    private lateinit var context: Context
    private var initialized = false
    private fun prefs() = context.getSharedPreferences("watch_downloads", Context.MODE_PRIVATE)
    private fun entries(): List<JSONObject> {
        val array = JSONArray(prefs().getString("items", "[]"))
        return (0 until array.length()).map { array.getJSONObject(it) }
    }
    private fun directory() = File(context.filesDir, "downloads").apply { mkdirs() }
    private fun key(id: String) = MessageDigest.getInstance("SHA-256").digest(id.toByteArray()).joinToString("") { "%02x".format(it) }

    @Synchronized fun init(appContext: Context) {
        if (initialized) return
        initialized = true
        context = appContext.applicationContext
        publish()
        scope.launch {
            runCatching {
                val buffer = Wearable.getDataClient(context).getDataItems(Uri.parse("wear://*$DOWNLOAD"), DataClient.FILTER_PREFIX).await()
                try { buffer.forEach { accept(DataMapItem.fromDataItem(it).dataMap) } } finally { buffer.release() }
            }
        }
    }

    fun accept(data: DataMap) {
        val metadata = data.getString("json") ?: return
        val asset = data.getAsset("audio")
        val pending = runCatching { JSONObject(metadata) }.getOrNull()
            ?.takeIf { it.optString("action") != "remove" }?.let { WatchTrack.from(it) }
        if (pending != null) _incoming.value = _incoming.value.filter { it.fileId != pending.fileId } + pending
        scope.launch {
            try { mutex.withLock {
                val entry = runCatching { JSONObject(metadata) }.getOrNull() ?: return@withLock
                val request = entry.optString("requestId")
                if (runCatching { UUID.fromString(request) }.isFailure) return@withLock
                if (entry.optString("action") == "remove") { removeEntry(entry); return@withLock }
                val cancelled = prefs().getStringSet("cancelled", emptySet()).orEmpty()
                if (prefs().getBoolean("signedOut", false)) { acknowledge(entry, "removed"); return@withLock }
                if (request in cancelled) { acknowledge(entry, "removed"); return@withLock }
                val existing = entries().firstOrNull { it.optString("requestId") == request }
                if (existing != null && File(directory(), existing.optString("localName")).exists()) { acknowledge(existing, "ready"); return@withLock }
                val bytes = entry.optLong("bytes")
                if (directory().usableSpace < bytes + 1_048_576) { acknowledge(entry, "failed", "storage_full"); return@withLock }
                if (asset == null || WatchTrack.from(entry) == null) { acknowledge(entry, "failed", "invalid_download"); return@withLock }
                val temporary = File(directory(), "$request.partial")
                try {
                    acknowledge(entry, "sending")
                    val response = Wearable.getDataClient(context).getFdForAsset(asset).await()
                    try { response.inputStream.use { input -> temporary.outputStream().use { output -> input.copyTo(output) } } }
                    finally { response.release() }
                    if (temporary.length() != bytes) error("Incomplete download")
                    val destination = File(directory(), request)
                    if (!temporary.renameTo(destination)) error("Could not save download")
                    entries().firstOrNull { it.optString("fileId") == entry.optString("fileId") }?.let { old -> File(directory(), old.optString("localName")).delete() }
                    entry.put("localName", request)
                    save(entries().filter { it.optString("fileId") != entry.optString("fileId") } + entry)
                    acknowledge(entry, "ready")
                } catch (_: Exception) { temporary.delete(); acknowledge(entry, "failed", "save_failed") }
            } } finally {
                if (pending != null) _incoming.value = _incoming.value.filter { it.fileId != pending.fileId }
            }
        }
    }

    fun localUri(track: WatchTrack): Uri? = entries().firstOrNull { it.optString("fileId") == track.fileId }
        ?.let { File(directory(), it.optString("localName")) }?.takeIf { it.exists() }?.let(Uri::fromFile)

    fun remove(track: WatchTrack) { scope.launch { mutex.withLock {
        entries().firstOrNull { it.optString("fileId") == track.fileId }?.let { removeEntry(it) }
    } } }

    fun setSignedOut(value: Boolean) {
        prefs().edit().putBoolean("signedOut", value).apply()
        if (value) clear()
    }

    fun clear() { scope.launch { mutex.withLock { entries().forEach { removeEntry(it) } } } }

    private suspend fun removeEntry(entry: JSONObject) {
        val cancelled = prefs().getStringSet("cancelled", emptySet()).orEmpty().toMutableSet()
        cancelled.add(entry.optString("requestId"))
        prefs().edit().putStringSet("cancelled", cancelled).apply()
        entries().firstOrNull { it.optString("requestId") == entry.optString("requestId") }?.let { existing ->
            File(directory(), existing.optString("localName")).delete()
            save(entries().filter { it.optString("requestId") != entry.optString("requestId") })
        }
        acknowledge(entry, "removed")
    }

    private fun save(items: List<JSONObject>) {
        prefs().edit().putString("items", JSONArray(items).toString()).apply()
        publish()
    }
    private fun publish() {
        _tracks.value = entries().mapNotNull { WatchTrack.from(it) }.filter { localUri(it) != null }
    }
    private suspend fun acknowledge(entry: JSONObject, state: String, error: String = "") {
        val payload = JSONObject(entry.toString()).apply {
            put("state", state); put("error", error); remove("localName"); remove("action")
        }
        val request = PutDataMapRequest.create(STATUS + key(entry.optString("fileId"))).apply {
            dataMap.putString("json", payload.toString())
        }.asPutDataRequest().setUrgent()
        runCatching { Wearable.getDataClient(context).putDataItem(request).await() }
    }
}

class WatchDownloadListenerService : WearableListenerService() {
    override fun onRequest(nodeId: String, path: String, request: ByteArray): com.google.android.gms.tasks.Task<ByteArray>? {
        if (path != "/medito/download-storage") return null
        return com.google.android.gms.tasks.Tasks.forResult(filesDir.usableSpace.toString().toByteArray())
    }
    override fun onDataChanged(events: DataEventBuffer) {
        WatchDownloads.init(applicationContext)
        events.filter { it.type == DataEvent.TYPE_CHANGED && it.dataItem.uri.path == "/medito/context" }
            .forEach { event ->
                DataMapItem.fromDataItem(event.dataItem).dataMap.getString("json")?.let { raw ->
                    WatchDownloads.setSignedOut(runCatching { JSONObject(raw).optBoolean("signedOut") }.getOrDefault(false))
                }
            }
        events.filter { it.type == DataEvent.TYPE_CHANGED && it.dataItem.uri.path?.startsWith(WatchDownloads.DOWNLOAD) == true }
            .forEach { WatchDownloads.accept(DataMapItem.fromDataItem(it.dataItem).dataMap) }
    }
}
