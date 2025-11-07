package meditofoundation.medito.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.LocalSize
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.actionStartActivity
import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import meditofoundation.medito.MainActivity

class ConsistencyWidget : GlanceAppWidget() {

    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override val sizeMode: SizeMode
        get() = SizeMode.Single

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            WidgetContent(context)
        }
    }

    @Composable
    private fun WidgetContent(context: Context) {
        val prefs = currentState<HomeWidgetGlanceState>().preferences
        val consistencyScore = prefs.getInt("consistency_score", 0)
        val totalTracksCompleted = prefs.getInt("total_tracks_completed", 0)

        // Medito colors
        val backgroundColor = Color(0xFFF8F9FA) // lightBackground
        val accentColor = Color(0xffef5e55) // amber
        val textColor = Color(0xFF000000) // black
        val secondaryTextColor = Color(0xFF000000) // black
        val checkmarkColor = Color(0xFF917DF0) // lightPurple

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(backgroundColor)
                .padding(20.dp)
                .clickable(onClick = actionStartActivity<MainActivity>(context))
        ) {
            Column(
                modifier = GlanceModifier.fillMaxSize(),
                verticalAlignment = Alignment.Vertical.CenterVertically,
                horizontalAlignment = Alignment.Horizontal.CenterHorizontally
            ) {
                // Consistency score section - centered
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Vertical.CenterVertically,
                    horizontalAlignment = Alignment.Horizontal.CenterHorizontally
                ) {
                    Text(
                        text = consistencyScore.toString(),
                        style = TextStyle(
                            fontSize = 36.sp,
                            fontWeight = FontWeight.Bold,
                            color = ColorProvider(textColor)
                        )
                    )
                    Spacer(modifier = GlanceModifier.width(6.dp))
                    Text(
                        text = "%",
                        style = TextStyle(
                            fontSize = 20.sp,
                            color = ColorProvider(textColor)
                        )
                    )
                }

                Spacer(modifier = GlanceModifier.height(8.dp))

                // Label
                Text(
                    text = "Consistency",
                    style = TextStyle(
                        fontSize = 14.sp,
                        color = ColorProvider(secondaryTextColor)
                    )
                )

                Spacer(modifier = GlanceModifier.height(8.dp))

                // Total sessions count in tiny text
                Text(
                    text = "$totalTracksCompleted sessions",
                    style = TextStyle(
                        fontSize = 9.sp,
                        color = ColorProvider(secondaryTextColor)
                    )
                )
            }
        }
    }
}
