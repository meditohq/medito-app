package meditofoundation.medito

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import meditofoundation.medito.pigeon.MeditoAppIconManager

class AppIconManagerImpl(private val context: Context) : MeditoAppIconManager {

    companion object {
        // The alias name used for the default (dusk) icon. Null iconName in Dart maps to this.
        private const val DEFAULT_ALIAS = "dusk"
    }

    // Discovers all launcher activity aliases for this package.
    // MainActivity itself no longer has a LAUNCHER intent filter, so only aliases appear here.
    private fun findAliasComponents(): Map<String, ComponentName> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
            `package` = context.packageName
        }
        val resolveInfos = pm.queryIntentActivities(intent, PackageManager.GET_DISABLED_COMPONENTS)

        val aliases = mutableMapOf<String, ComponentName>()
        for (info in resolveInfos) {
            val name = info.activityInfo.name
            val markerIndex = name.indexOf(".MainActivity.")
            if (markerIndex >= 0) {
                val iconName = name.substring(markerIndex + ".MainActivity.".length)
                aliases[iconName] = ComponentName(context.packageName, name)
            }
        }
        return aliases
    }

    // Returns null when the default (dusk) alias is active, matching iOS plugin behaviour.
    override fun getAlternateIconName(callback: (Result<String?>) -> Unit) {
        val pm = context.packageManager
        for ((iconName, component) in findAliasComponents()) {
            if (pm.getComponentEnabledSetting(component) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                callback(Result.success(if (iconName == DEFAULT_ALIAS) null else iconName))
                return
            }
        }
        callback(Result.success(null))
    }

    // null means "restore default" — we enable the dusk alias.
    // MainActivity is never touched so flutter run always works.
    override fun setAlternateIconName(iconName: String?, callback: (Result<Unit>) -> Unit) {
        try {
            val pm = context.packageManager
            val aliases = findAliasComponents()
            val targetName = if (iconName.isNullOrEmpty()) DEFAULT_ALIAS else iconName

            val target = aliases[targetName]
                ?: return callback(Result.failure(Exception("Icon '$targetName' not found. Available: ${aliases.keys}")))

            for ((_, component) in aliases) {
                pm.setComponentEnabledSetting(
                    component,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
            pm.setComponentEnabledSetting(
                target,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP,
            )
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }
}
