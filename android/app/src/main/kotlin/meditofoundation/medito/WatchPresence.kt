package meditofoundation.medito

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.ContextCompat
import androidx.wear.remote.interactions.RemoteActivityHelper
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.BinaryMessenger
import meditofoundation.medito.pigeon.WatchPresenceApi
import meditofoundation.medito.pigeon.WatchStatus

/**
 * Tells Dart whether this phone has a Wear OS watch and whether the Medito
 * watch app is on it (analytics + the Settings install prompt), and opens the
 * watch's Play Store on Medito so it can be installed.
 *
 * A watch counts as paired when the Data Layer sees one, or when a companion
 * app is installed (declared in the manifest's <queries>) — that also covers
 * phones without Play services' Wearable API. The app counts as installed when
 * any watch advertises the `medito_watch_app` capability (android/wear wear.xml).
 */
class WatchPresence private constructor(private val context: Context) : WatchPresenceApi {
    companion object {
        private const val CAPABILITY = "medito_watch_app"
        private val companionPackages = listOf(
            "com.google.android.wearable.app", // Wear OS by Google
            "com.google.android.apps.wear.companion", // Pixel Watch
            "com.samsung.android.app.watchmanager", // Galaxy Wearable
        )

        fun register(messenger: BinaryMessenger, context: Context) {
            WatchPresenceApi.setUp(messenger, WatchPresence(context.applicationContext))
        }
    }

    override fun getStatus(callback: (Result<WatchStatus>) -> Unit) {
        val companion = companionPackages.any { isInstalled(it) }
        val nodes = Wearable.getNodeClient(context).connectedNodes
        val capability = Wearable.getCapabilityClient(context)
            .getCapability(CAPABILITY, CapabilityClient.FILTER_ALL)
        Tasks.whenAllComplete(nodes, capability).addOnCompleteListener {
            val connected = if (nodes.isSuccessful) nodes.result.orEmpty() else emptyList()
            val withApp = if (capability.isSuccessful) capability.result.nodes else emptySet()
            callback(
                Result.success(
                    WatchStatus(
                        paired = companion || connected.isNotEmpty(),
                        appInstalled = withApp.isNotEmpty(),
                    )
                )
            )
        }
    }

    override fun openWatchInstall(callback: (Result<Boolean>) -> Unit) {
        val nodes = Wearable.getNodeClient(context).connectedNodes
        val capability = Wearable.getCapabilityClient(context)
            .getCapability(CAPABILITY, CapabilityClient.FILTER_ALL)
        Tasks.whenAllComplete(nodes, capability).addOnCompleteListener {
            val connected = if (nodes.isSuccessful) nodes.result.orEmpty() else emptyList()
            val withApp = if (capability.isSuccessful) capability.result.nodes.map { it.id }.toSet() else emptySet()
            val targets = connected.filter { it.id !in withApp }
            if (targets.isEmpty()) return@addOnCompleteListener callback(Result.success(false))
            openOnWatches(targets, callback)
        }
    }

    /** Opens Medito's Play Store listing on each watch; true if any opened. */
    private fun openOnWatches(targets: List<Node>, callback: (Result<Boolean>) -> Unit) {
        val intent = Intent(Intent.ACTION_VIEW)
            .addCategory(Intent.CATEGORY_BROWSABLE)
            .setData(Uri.parse("market://details?id=${context.packageName}"))
        val helper = RemoteActivityHelper(context)
        val executor = ContextCompat.getMainExecutor(context)
        var remaining = targets.size
        var opened = false
        targets.forEach { node ->
            val future = helper.startRemoteActivity(intent, node.id)
            future.addListener({
                opened = opened || runCatching { future.get() }.isSuccess
                if (--remaining == 0) callback(Result.success(opened))
            }, executor)
        }
    }

    private fun isInstalled(pkg: String): Boolean = try {
        context.packageManager.getPackageInfo(pkg, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }
}
