package meditofoundation.medito

internal data class LauncherIconState(
    val name: String,
    val enabled: Boolean,
    val explicitlyEnabled: Boolean,
)

internal class LauncherIconReconciler(private val defaultName: String) {
    fun selectedIcon(icons: List<LauncherIconState>): LauncherIconState? {
        // An explicit choice survives an update, even if that update introduces
        // another alias which is enabled by default in the new manifest.
        val enabled = icons.filter { it.enabled }
        if (enabled.size == 1) return enabled.single()
        val explicit = enabled.filter { it.explicitlyEnabled }
        return when (explicit.size) {
            0 -> enabled.singleOrNull { it.name == defaultName }
            1 -> explicit.single()
            // With multiple explicit overrides we cannot recover the user's
            // last choice. Leave the launcher alone rather than guessing.
            else -> null
        }
    }

    fun reconcile(icons: List<LauncherIconState>, disable: (String) -> Unit) {
        // This is only a duplicate-entry repair. In particular, an empty query
        // or a stale launcher shortcut must never cause us to enable an alias.
        if (icons.count { it.enabled } < 2) return
        val selected = selectedIcon(icons) ?: return
        for (icon in icons) {
            if (icon.enabled && icon.name != selected.name) disable(icon.name)
        }
    }
}
