package meditofoundation.medito

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import meditofoundation.medito.pigeon.MeditoAppIconManager

class AppIconManagerImpl(private val context: Context) : MeditoAppIconManager {

    companion object {
        // The alias name used for the default (classic) icon. Null iconName in Dart maps to this.
        private const val DEFAULT_ALIAS = "classic"
    }

    private val reconciler = LauncherIconReconciler(DEFAULT_ALIAS)

    private fun launcherIntent() = Intent(Intent.ACTION_MAIN).apply {
        addCategory(Intent.CATEGORY_LAUNCHER)
        `package` = context.packageName
    }

    // Only manage icon aliases. MainActivity must stay enabled for links and
    // Flutter tooling (debug builds also expose it as a launcher activity).
    private fun findAliasComponents(): Map<String, ComponentName> {
        val pm = context.packageManager
        val resolveInfos = pm.queryIntentActivities(launcherIntent(), PackageManager.MATCH_DISABLED_COMPONENTS)

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

    private fun iconStates(aliases: Map<String, ComponentName>): List<LauncherIconState> {
        val pm = context.packageManager
        // A DEFAULT component can still be enabled by its manifest. Query the
        // effective state rather than treating DEFAULT as disabled.
        val enabledComponents = pm.queryIntentActivities(launcherIntent(), 0)
            .map { it.activityInfo.name }.toSet()
        return aliases.map { (name, component) ->
            LauncherIconState(
                name = name,
                enabled = component.className in enabledComponents,
                explicitlyEnabled = pm.getComponentEnabledSetting(component) ==
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            )
        }
    }

    fun repairDuplicateLauncherIcons() {
        try {
            val aliases = findAliasComponents()
            reconciler.reconcile(iconStates(aliases)) { name ->
                context.packageManager.setComponentEnabledSetting(
                    aliases.getValue(name),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
        } catch (e: Exception) {
            // A launcher/PackageManager failure must not prevent opening Medito.
            Log.w("AppIcon", "Could not reconcile launcher icons", e)
        }
    }

    // Returns null when the default (classic) alias is active, matching iOS plugin behaviour.
    override fun getAlternateIconName(callback: (Result<String?>) -> Unit) {
        try {
            val name = reconciler.selectedIcon(iconStates(findAliasComponents()))?.name
            callback(Result.success(if (name == DEFAULT_ALIAS) null else name))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    // null means "restore default" — we enable the classic alias.
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
