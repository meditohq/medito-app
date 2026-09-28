package meditofoundation.medito.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.util.Log
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver

/**
 * Extends GlanceAppWidgetReceiver directly rather than home_widget's
 * HomeWidgetGlanceWidgetReceiver: that class's onUpdate re-runs every widget update inside
 * runBlocking on the main thread, on top of Glance's own onUpdate which already does the same
 * work off-main via goAsync. The blocking copy ANRs the process (killing any playing session)
 * when the update stalls. Glance's update() reloads HomeWidgetGlanceState itself, so dropping
 * home_widget's identity state write loses nothing.
 *
 * Updating an ID the host has already deleted throws "Invalid AppWidget ID.".
 * Some OEM framework builds dispatch onUpdate on a posted Handler, outside our onReceive
 * try/catch, so the throw crashes the process. Drop stale IDs first and catch as a backstop.
 */
abstract class SafeGlanceWidgetReceiver<T : GlanceAppWidget> : GlanceAppWidgetReceiver() {

    abstract override val glanceAppWidget: T

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val validIds = appWidgetIds.filter { appWidgetManager.getAppWidgetInfo(it) != null }.toIntArray()
        if (validIds.isEmpty()) return
        try {
            super.onUpdate(context, appWidgetManager, validIds)
        } catch (e: IllegalArgumentException) {
            Log.w(javaClass.simpleName, "Ignoring update for stale widget ID: ${e.message}")
        }
    }
}
