package meditofoundation.medito

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.Text

class StatsWidget : GlanceAppWidget() {
    companion object {
        suspend fun updateStats(context: Context) {
            val manager = GlanceAppWidgetManager(context)
            val glanceIds = manager.getGlanceIds(StatsWidget::class.java)
            val widget = StatsWidget()
            glanceIds.forEach { glanceId ->
                widget.update(context, glanceId)
            }
        }
    }

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            StatsWidgetContent(context)
        }
    }
}

@Composable
private fun StatsWidgetContent(context: Context) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.Start,
        verticalAlignment = Alignment.Top
    ) {
        Text(
            text = "Current Streak",

            )
        Text(
            text = "${getStreakValue(context)} days",

            )

        Text(
            text = "Time Listened",

            modifier = GlanceModifier.padding(top = 8.dp)
        )
        Text(
            text = "${getTimeListened(context)} minutes",

            )

        Text(
            text = "Tracks Completed",
            modifier = GlanceModifier.padding(top = 8.dp)
        )
        Text(
            text = getTracksCompleted(context),
        )
    }
}

private fun getStreakValue(context: Context): String {
    return context.getSharedPreferences("home_widget", Context.MODE_PRIVATE)
        .getString("streakValue", "0") ?: "0"
}

private fun getTimeListened(context: Context): String {
    return context.getSharedPreferences("home_widget", Context.MODE_PRIVATE)
        .getString("timeListened", "0") ?: "0"
}

private fun getTracksCompleted(context: Context): String {
    return context.getSharedPreferences("home_widget", Context.MODE_PRIVATE)
        .getString("tracksCompleted", "0") ?: "0"
}

class StatsWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = StatsWidget()
} 