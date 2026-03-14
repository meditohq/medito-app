package meditofoundation.medito.widget

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.glance.appwidget.updateAll
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class UpNextWidgetReceiver : HomeWidgetGlanceWidgetReceiver<UpNextWidget>() {
    override val glanceAppWidget = UpNextWidget()

    private val receiverScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val tag = "UpNextWidget"

    private fun updateWidget(context: Context) {
        receiverScope.launch {
            try {
                glanceAppWidget.updateAll(context.applicationContext)
                Log.d(tag, "Widget updateAll() completed")
            } catch (e: Exception) {
                Log.e(tag, "Error updating widget", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "es.antonborri.home_widget.UPDATE_WIDGET") {
            updateWidget(context)
        }
    }
}
