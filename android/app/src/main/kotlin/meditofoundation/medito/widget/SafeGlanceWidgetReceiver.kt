package meditofoundation.medito.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.util.Log
import androidx.glance.appwidget.GlanceAppWidget
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

/**
 * home_widget's onUpdate calls GlanceAppWidgetManager.getGlanceIdBy for every ID in the
 * broadcast, which throws "Invalid AppWidget ID." for an ID the host has already deleted.
 * Some OEM framework builds dispatch onUpdate on a posted Handler, outside our onReceive
 * try/catch, so the throw crashes the process. Drop stale IDs first and catch as a backstop.
 */
abstract class SafeGlanceWidgetReceiver<T : GlanceAppWidget> : HomeWidgetGlanceWidgetReceiver<T>() {

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
