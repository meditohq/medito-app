package meditofoundation.medito

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LauncherIconReconcilerTest {
    private val reconciler = LauncherIconReconciler("classic")

    @Test fun upgradeKeepsOldChoiceAndRemovesNewDefault() {
        // The old app had no Classic alias, so it has no disabled override
        // when an update introduces Classic as the new manifest default.
        for (choice in listOf("dusk", "purple", "pink", "forest")) {
            val icons = listOf(
                LauncherIconState("classic", enabled = true, explicitlyEnabled = false),
                LauncherIconState(choice, enabled = true, explicitlyEnabled = true),
            )
            assertEquals(choice, reconciler.selectedIcon(icons)?.name)
            assertEquals(listOf("classic" to false), changes(icons))
            assertEquals(listOf("classic" to false), changes(icons.reversed()))
        }
    }

    @Test fun freshInstallKeepsManifestDefaultWithoutWritingOverrides() {
        val icons = listOf(
            LauncherIconState("classic", enabled = true, explicitlyEnabled = false),
            LauncherIconState("dusk", enabled = false, explicitlyEnabled = false),
        )
        assertEquals("classic", reconciler.selectedIcon(icons)?.name)
        assertTrue(changes(icons).isEmpty())
    }

    @Test fun existingAlternateChoiceNeedsNoChanges() {
        val icons = listOf(
            LauncherIconState("classic", enabled = false, explicitlyEnabled = false),
            LauncherIconState("ocean", enabled = true, explicitlyEnabled = true),
        )
        assertEquals("ocean", reconciler.selectedIcon(icons)?.name)
        assertTrue(changes(icons).isEmpty())
    }

    @Test fun manifestEnabledAlternateIsRecognizedWithoutAnOverride() {
        val icons = listOf(
            LauncherIconState("classic", enabled = false, explicitlyEnabled = false),
            LauncherIconState("dusk", enabled = true, explicitlyEnabled = false),
        )
        assertEquals("dusk", reconciler.selectedIcon(icons)?.name)
        assertTrue(changes(icons).isEmpty())
    }

    @Test fun emptyEnabledQueryDoesNotEnableAnyIcons() {
        val icons = listOf(
            LauncherIconState("classic", enabled = false, explicitlyEnabled = false),
            LauncherIconState("dusk", enabled = false, explicitlyEnabled = false),
        )
        assertTrue(changes(icons).isEmpty())
    }

    @Test fun duplicateManifestDefaultsKeepClassic() {
        val icons = listOf(
            LauncherIconState("dusk", enabled = true, explicitlyEnabled = false),
            LauncherIconState("classic", enabled = true, explicitlyEnabled = false),
        )
        assertEquals(listOf("dusk" to false), changes(icons))
    }

    @Test fun repeatedRepairDoesNotTouchLauncherAgain() {
        var icons = listOf(
            LauncherIconState("classic", enabled = true, explicitlyEnabled = false),
            LauncherIconState("pink", enabled = true, explicitlyEnabled = true),
        )
        reconciler.reconcile(icons) { name ->
            icons = icons.map {
                if (it.name == name) it.copy(enabled = false, explicitlyEnabled = false) else it
            }
        }
        assertEquals(listOf("pink"), icons.filter { it.enabled }.map { it.name })
        assertTrue(changes(icons).isEmpty())
    }

    @Test fun ambiguousExplicitChoicesAreLeftAlone() {
        val icons = listOf(
            LauncherIconState("pink", enabled = true, explicitlyEnabled = true),
            LauncherIconState("forest", enabled = true, explicitlyEnabled = true),
        )
        assertNull(reconciler.selectedIcon(icons))
        assertTrue(changes(icons).isEmpty())
        assertTrue(changes(icons.reversed()).isEmpty())
    }

    @Test fun ambiguousDefaultsWithoutClassicAreLeftAlone() {
        val icons = listOf(
            LauncherIconState("dusk", enabled = true, explicitlyEnabled = false),
            LauncherIconState("forest", enabled = true, explicitlyEnabled = false),
        )
        assertNull(reconciler.selectedIcon(icons))
        assertTrue(changes(icons).isEmpty())
    }

    @Test fun everyHealthyIconChoiceIsUntouchedEvenIfLauncherDisplaysAStaleDuplicate() {
        val names = listOf("classic", "dusk", "purple", "nearblack", "blush", "ocean", "forest", "pink")
        for (choice in names) {
            for (explicit in listOf(false, true)) {
                val icons = names.map { name ->
                    LauncherIconState(name, enabled = name == choice, explicitlyEnabled = explicit && name == choice)
                }
                assertEquals(choice, reconciler.selectedIcon(icons)?.name)
                assertTrue("Must not change a single active icon: $choice", changes(icons).isEmpty())
            }
        }
    }

    @Test fun allStateCombinationsKeepAnExistingActiveIcon() {
        val names = listOf("classic", "dusk", "pink", "forest")
        // Each icon is disabled, manifest-enabled, or explicitly enabled.
        for (combination in 0 until 81) {
            var remaining = combination
            val icons = names.map { name ->
                val state = remaining % 3
                remaining /= 3
                LauncherIconState(name, enabled = state != 0, explicitlyEnabled = state == 2)
            }
            val changes = changes(icons)
            val stillEnabled = icons.filter { it.enabled && (it.name to false) !in changes }
            if (icons.any { it.enabled }) assertTrue(stillEnabled.isNotEmpty())
            if (icons.count { it.enabled } <= 1) assertTrue(changes.isEmpty())
            if (icons.count { it.explicitlyEnabled } > 1) assertTrue(changes.isEmpty())
        }
    }

    @Test fun missingAliasesDoNotChangeAnything() {
        assertTrue(changes(emptyList()).isEmpty())
    }

    private fun changes(icons: List<LauncherIconState>): List<Pair<String, Boolean>> {
        val changes = mutableListOf<Pair<String, Boolean>>()
        reconciler.reconcile(icons) { name -> changes.add(name to false) }
        return changes
    }
}
