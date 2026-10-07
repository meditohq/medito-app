package meditofoundation.medito

import android.content.Context
import android.content.pm.PackageManager
import io.flutter.plugin.common.BinaryMessenger
import meditofoundation.medito.pigeon.WatchPresenceApi
import meditofoundation.medito.pigeon.WatchStatus

/**
 * Tells Dart whether this phone has a Wear OS watch set up, so analytics can
 * size the audience for a watch app. Owning one shows up as its companion app
 * being installed (declared in the manifest's <queries>).
 */
class WatchPresence private constructor(private val context: Context) : WatchPresenceApi {
    companion object {
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
        callback(
            Result.success(
                WatchStatus(
                    paired = companionPackages.any { isInstalled(it) },
                    // No Medito Wear OS app on this build yet.
                    appInstalled = false,
                )
            )
        )
    }

    private fun isInstalled(pkg: String): Boolean = try {
        context.packageManager.getPackageInfo(pkg, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }
}
