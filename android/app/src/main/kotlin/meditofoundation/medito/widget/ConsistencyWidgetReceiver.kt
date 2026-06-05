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

class ConsistencyWidgetReceiver : HomeWidgetGlanceWidgetReceiver<ConsistencyWidget>() {
    override val glanceAppWidget = ConsistencyWidget()

    private val receiverScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val TAG = "ConsistencyWidget"

    override fun onReceive(context: Context, intent: Intent) {
        try {
            super.onReceive(context, intent)
        } catch (e: IllegalArgumentException) {
            // Stale broadcast referencing a widget ID that no longer exists.
            Log.w(TAG, "Ignoring stale widget broadcast: ${e.message}")
            return
        }

        if (intent.action == "es.antonborri.home_widget.UPDATE_WIDGET") {
            val pending = goAsync()
            receiverScope.launch {
                try {
                    glanceAppWidget.updateAll(context.applicationContext)
                } catch (e: Exception) {
                    Log.e(TAG, "Error updating widget", e)
                } finally {
                    pending.finish()
                }
            }
        }
    }
}

