package meditofoundation.medito.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.glance.appwidget.updateAll
import HomeWidgetGlanceWidgetReceiver
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class ConsistencyWidgetReceiver : HomeWidgetGlanceWidgetReceiver<ConsistencyWidget>() {
    override val glanceAppWidget = ConsistencyWidget()
    
    private val receiverScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val TAG = "ConsistencyWidget"
    
    private fun updateWidget(context: Context) {
        // Use application context for Glance widget updates
        val appContext = context.applicationContext
        Log.d(TAG, "🔄 Updating widget via updateAll()")
        receiverScope.launch {
            try {
                glanceAppWidget.updateAll(appContext)
                Log.d(TAG, "✅ Widget updateAll() completed successfully")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error updating widget", e)
            }
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        // Handle update requests from home_widget package
        // When HomeWidget.updateWidget() is called, it sends a broadcast
        // We need to explicitly update all widget instances for Glance widgets
        val action = intent.action
        Log.d(TAG, "📨 onReceive called with action: $action")
        
        // Handle home_widget specific updates
        if (action == "es.antonborri.home_widget.UPDATE_WIDGET") {
            Log.d(TAG, "✅ Received home_widget UPDATE_WIDGET broadcast, triggering update")
            updateWidget(context)
        }
        // Handle standard widget updates
        else if (action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            Log.d(TAG, "✅ Received APPWIDGET_UPDATE broadcast, updating widget")
            updateWidget(context)
        } else {
            Log.d(TAG, "ℹ️ Ignoring action: $action")
        }
    }
}

