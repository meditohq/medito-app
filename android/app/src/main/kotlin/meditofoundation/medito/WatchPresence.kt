package meditofoundation.medito

import android.content.Context
import android.content.pm.PackageManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Tells Dart whether this phone has a Wear OS watch set up, so analytics can
 * size the audience for a watch app. Owning one shows up as its companion app
 * being installed (declared in the manifest's <queries>).
 */
object WatchPresence {
    private val companionPackages = listOf(
        "com.google.android.wearable.app", // Wear OS by Google
        "com.google.android.apps.wear.companion", // Pixel Watch
        "com.samsung.android.app.watchmanager", // Galaxy Wearable
    )

    fun register(messenger: BinaryMessenger, context: Context) {
        val appContext = context.applicationContext
        MethodChannel(messenger, "medito.app/watch_presence").setMethodCallHandler { call, result ->
            if (call.method != "getStatus") return@setMethodCallHandler result.notImplemented()
            result.success(
                mapOf(
                    "paired" to companionPackages.any { isInstalled(appContext, it) },
                    // No Medito Wear OS app on this build yet.
                    "appInstalled" to false,
                )
            )
        }
    }

    private fun isInstalled(context: Context, pkg: String): Boolean = try {
        context.packageManager.getPackageInfo(pkg, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }
}
