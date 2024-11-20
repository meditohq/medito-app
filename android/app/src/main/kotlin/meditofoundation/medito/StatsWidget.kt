package meditofoundation.medito

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.compose.ui.graphics.Color

class StatsWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            StatsWidgetContent(context)
        }
    }
}

@Composable
private fun StatsWidgetContent(context: Context) {
    val white = ColorProvider(Color.White)
    val gray = ColorProvider(Color.Gray)
    val black = ColorProvider(Color.Black)

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(white)
            .padding(16),
        horizontalAlignment = Alignment.Start,
        verticalAlignment = Alignment.Top
    ) {
        Text(
            text = "Current Streak",
            style = TextStyle(color = gray)
        )
        Text(
            text = "${getStreakValue(context)} days",
            style = TextStyle(color = black)
        )
        
        Text(
            text = "Time Listened",
            style = TextStyle(color = gray),
            modifier = GlanceModifier.padding(top = 8)
        )
        Text(
            text = "${getTimeListened(context)} minutes",
            style = TextStyle(color = black)
        )
        
        Text(
            text = "Tracks Completed",
            style = TextStyle(color = gray),
            modifier = GlanceModifier.padding(top = 8)
        )
        Text(
            text = getTracksCompleted(context),
            style = TextStyle(color = black)
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