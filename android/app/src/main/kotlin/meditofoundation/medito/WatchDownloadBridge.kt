package meditofoundation.medito

import android.content.Context
import android.net.Uri
import com.google.android.gms.wearable.*
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.UUID

/** Persistent phone intentions; readiness is confirmed by the receiving watch. */
object WatchDownloadBridge {
    private var sink: io.flutter.plugin.common.EventChannel.EventSink? = null
    private val main = android.os.Handler(android.os.Looper.getMainLooper())
    private fun changed() { main.post { sink?.success(null) } }
    fun register(messenger: io.flutter.plugin.common.BinaryMessenger, context: Context) {
        val capabilityListener = CapabilityClient.OnCapabilityChangedListener { changed() }
        io.flutter.plugin.common.EventChannel(messenger, "medito.app/watch/downloads")
            .setStreamHandler(object : io.flutter.plugin.common.EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: io.flutter.plugin.common.EventChannel.EventSink) {
                    sink = events
                    Wearable.getCapabilityClient(context).addListener(capabilityListener, "medito_watch_app")
                }
                override fun onCancel(arguments: Any?) {
                    sink = null
                    Wearable.getCapabilityClient(context).removeListener(capabilityListener, "medito_watch_app")
                }
            })
    }
    const val DOWNLOAD = "/medito/download/"
    const val STATUS = "/medito/download-status/"
    private fun prefs(context: Context) = context.getSharedPreferences("medito_watch_downloads", Context.MODE_PRIVATE)
    private fun entries(context: Context): List<JSONObject> {
        val array = JSONArray(prefs(context).getString("items", "[]"))
        return (0 until array.length()).map { array.getJSONObject(it) }
    }
    @Synchronized private fun put(context: Context, item: JSONObject, notify: Boolean = true) {
        val all = entries(context).toMutableList()
        val index = all.indexOfFirst { it.optString("fileId") == item.optString("fileId") }
        if (index >= 0) all[index] = item else all.add(item)
        prefs(context).edit().putString("items", JSONArray(all).toString()).apply()
        if (notify) changed()
    }
    private fun key(id: String) = MessageDigest.getInstance("SHA-256").digest(id.toByteArray()).joinToString("") { "%02x".format(it) }
    private fun map(json: JSONObject): Map<String, Any?> = json.keys().asSequence().associateWith {
        val value = json.get(it)
        if (value == JSONObject.NULL) null else value
    }

    fun setSignedOut(context: Context, value: Boolean) {
        prefs(context).edit().putBoolean("signedOut", value).apply()
        if (value) clear(context)
    }

    private fun availability(context: Context, capability: CapabilityInfo, callback: (Boolean) -> Unit) {
        if (capability.nodes.isNotEmpty()) {
            prefs(context).edit().putBoolean("knownWatch", true)
                .putStringSet("knownNodes", capability.nodes.map { it.id }.toSet()).apply()
            callback(true)
            return
        }
        Wearable.getNodeClient(context).connectedNodes.addOnSuccessListener { connected ->
            val knownNodes = prefs(context).getStringSet("knownNodes", emptySet()).orEmpty()
            // An offline watch can wait. A connected watch that removed Medito needs setup again.
            if (connected.any { it.id in knownNodes }) prefs(context).edit().putBoolean("knownWatch", false).apply()
            callback(prefs(context).getBoolean("knownWatch", false))
        }.addOnFailureListener { callback(prefs(context).getBoolean("knownWatch", false)) }
    }

    fun snapshot(context: Context, result: MethodChannel.Result) {
        Wearable.getCapabilityClient(context).getCapability("medito_watch_app", CapabilityClient.FILTER_ALL)
            .addOnSuccessListener { capability ->
                availability(context, capability) { available ->
                    Wearable.getDataClient(context).getDataItems(Uri.parse("wear://*$STATUS"), DataClient.FILTER_PREFIX)
                        .addOnSuccessListener { buffer ->
                            try { buffer.forEach { item -> DataMapItem.fromDataItem(item).dataMap.getString("json")?.let { receive(context, it, notify = false) } } }
                            finally { buffer.release() }
                            result.success(mapOf("available" to available, "items" to entries(context).map(::map)))
                        }.addOnFailureListener { result.success(mapOf("available" to available, "items" to entries(context).map(::map))) }
                }
            }.addOnFailureListener { result.success(mapOf("available" to false, "items" to entries(context).map(::map))) }
    }

    fun send(context: Context, payload: Map<*, *>, result: MethodChannel.Result) {
        val id = payload["fileId"] as? String ?: return result.error("invalid_download", null, null)
        val file = (payload["path"] as? String)?.let(::File)
            ?: return result.error("missing_download", null, null)
        if (!file.exists()) return result.error("missing_download", null, null)
        if (entries(context).any { it.optString("fileId") == id && it.optString("state") in listOf("ready", "queued", "sending") }) return result.success(null)
        Wearable.getCapabilityClient(context).getCapability("medito_watch_app", CapabilityClient.FILTER_ALL)
            .addOnSuccessListener { capability ->
                if (capability.nodes.isEmpty()) {
                    availability(context, capability) { available ->
                        if (available) queue(context, payload, id, file, result)
                        else result.error("watch_unavailable", null, null)
                    }
                    return@addOnSuccessListener
                }
                prefs(context).edit().putBoolean("knownWatch", true)
                    .putStringSet("knownNodes", capability.nodes.map { it.id }.toSet()).apply()
                com.google.android.gms.tasks.Tasks.withTimeout(
                    Wearable.getMessageClient(context).sendRequest(capability.nodes.first().id, "/medito/download-storage", byteArrayOf()),
                    3, java.util.concurrent.TimeUnit.SECONDS,
                ).addOnSuccessListener { response ->
                    val free = response.toString(Charsets.UTF_8).toLongOrNull()
                    val reserved = entries(context).filter { it.optString("state") in listOf("queued", "sending") }.sumOf { it.optLong("bytes") }
                    if (free != null && free < (file.length() + reserved) * 2 + 1_048_576) result.error("storage_full", null, null)
                    else queue(context, payload, id, file, result)
                }.addOnFailureListener { queue(context, payload, id, file, result) }
            }.addOnFailureListener { result.error("watch_unavailable", it.message, null) }
    }

    private fun queue(context: Context, payload: Map<*, *>, id: String, file: File, result: MethodChannel.Result) {
        if (prefs(context).getBoolean("signedOut", false)) { result.error("watch_unavailable", null, null); return }
        if (entries(context).any { it.optString("fileId") == id && it.optString("state") in listOf("ready", "queued", "sending") }) { result.success(null); return }
        val requestId = UUID.randomUUID().toString()
        val entry = JSONObject(payload).apply {
            remove("path")
            put("requestId", requestId)
            put("state", "queued")
        }
        // Staging protects a queued transfer when the phone copy is removed.
        val staging = File(context.filesDir, "watch-outgoing").apply { mkdirs() }
        val staged = File(staging, requestId)
        try { file.copyTo(staged) } catch (e: Exception) { result.error("transfer_failed", e.message, null); return }
        entry.put("stagedPath", staged.path)
        put(context, entry)
        val metadata = JSONObject(entry.toString()).apply { remove("stagedPath"); put("action", "send") }
        val data = PutDataMapRequest.create(DOWNLOAD + key(id)).apply {
            dataMap.putString("json", metadata.toString())
            dataMap.putAsset("audio", Asset.createFromUri(Uri.fromFile(staged)))
        }.asPutDataRequest().setUrgent()
        Wearable.getDataClient(context).putDataItem(data)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { entry.put("state", "failed"); put(context, entry); staged.delete(); result.error("transfer_failed", it.message, null) }
    }

    fun remove(context: Context, payload: Map<*, *>, result: MethodChannel.Result) {
        val id = payload["fileId"] as? String ?: return result.error("invalid_download", null, null)
        val entry = entries(context).firstOrNull { it.optString("fileId") == id } ?: return result.success(null)
        val cancelled = prefs(context).getStringSet("cancelled", emptySet()).orEmpty().toMutableSet()
        cancelled.add(entry.optString("requestId"))
        prefs(context).edit().putStringSet("cancelled", cancelled).apply()
        entry.put("state", "removing")
        put(context, entry)
        val metadata = JSONObject(entry.toString()).apply { remove("stagedPath"); put("action", "remove") }
        val data = PutDataMapRequest.create(DOWNLOAD + key(id)).apply { dataMap.putString("json", metadata.toString()) }
            .asPutDataRequest().setUrgent()
        Wearable.getDataClient(context).putDataItem(data).addOnSuccessListener { result.success(null) }
            .addOnFailureListener { result.error("transfer_failed", it.message, null) }
    }

    fun clear(context: Context) {
        for (entry in entries(context)) {
            remove(context, map(entry), object : MethodChannel.Result {
                override fun success(result: Any?) {}
                override fun error(code: String, message: String?, details: Any?) {}
                override fun notImplemented() {}
            })
            entry.optString("stagedPath").takeIf { it.isNotEmpty() }?.let { File(it).delete() }
        }
        prefs(context).edit().putString("items", "[]").apply()
    }

    @Synchronized fun receive(context: Context, raw: String, notify: Boolean = true) {
        val status = runCatching { JSONObject(raw) }.getOrNull() ?: return
        if (prefs(context).getBoolean("signedOut", false)) return
        if (status.optString("state") != "removed" && status.optString("requestId") in prefs(context).getStringSet("cancelled", emptySet()).orEmpty()) return
        val id = status.optString("fileId")
        val current = entries(context).firstOrNull { it.optString("fileId") == id }
        if (current != null && current.optString("requestId") != status.optString("requestId")) return
        if (status.optString("state") in listOf("ready", "removed", "failed") && current != null && (current.optString("state") != "removing" || status.optString("state") == "removed")) {
            // The watch owns its saved copy. Release the replicated asset once acknowledged.
            Wearable.getDataClient(context).deleteDataItems(Uri.parse("wear://*$DOWNLOAD${key(id)}"), DataClient.FILTER_LITERAL)
        }
        if (status.optString("state") == "removed") {
            current?.optString("stagedPath")?.takeIf { it.isNotEmpty() }?.let { File(it).delete() }
            prefs(context).edit().putString("items", JSONArray(entries(context).filter { it.optString("fileId") != id }).toString()).apply()
        } else if (current?.optString("state") != "removing") {
            val entry = current ?: status
            entry.put("state", status.optString("state"))
            entry.put("error", status.optString("error"))
            if (entry.optString("state") in listOf("ready", "failed")) {
                entry.optString("stagedPath").takeIf { it.isNotEmpty() }?.let { File(it).delete() }
                entry.remove("stagedPath")
            }
            put(context, entry, notify)
        }
        if (notify && status.optString("state") == "removed") changed()
    }
}
