package meditofoundation.medito

import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider

class StatsWidget : GlanceAppWidget() {

    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceContent(currentState())
        }
    }

    @Composable
    private fun GlanceContent(currentState: HomeWidgetGlanceState) {
        val data = currentState.preferences
        val streakValue = data.getString("streakValue", "0")
        val timeListened = data.getString("timeListened", "0")
        val tracksCompleted = data.getString("tracksCompleted", "0")

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(Color.Black)
                .padding(16.dp)
        ) {
            Column(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .padding(16.dp),
                horizontalAlignment = Alignment.Start,
                verticalAlignment = Alignment.Top
            ) {
                Text(
                    text = "Current Streak",
                    style = TextStyle(
                        color = ColorProvider(Color.White),
                        fontSize = 14.sp
                    )
                )
                Text(
                    text = "$streakValue days",
                    style = TextStyle(
                        color = ColorProvider(Color.White),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                )

                Text(
                    text = "Time Listened",
                    style = TextStyle(
                        color = ColorProvider(Color.White),
                        fontSize = 14.sp
                    ),
                    modifier = GlanceModifier.padding(top = 8.dp)
                )
                Text(
                    text = "$timeListened minutes",
                    style = TextStyle(
                        color = ColorProvider(Color.White),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                )

                Text(
                    text = "Tracks Completed",
                    style = TextStyle(
                        color = ColorProvider(Color.White),
                        fontSize = 14.sp
                    ),
                    modifier = GlanceModifier.padding(top = 8.dp)
                )
                Text(
                    text = tracksCompleted ?: "!!",
                    style = TextStyle(
                        color = ColorProvider(Color.White),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                )
            }
        }
    }
}
