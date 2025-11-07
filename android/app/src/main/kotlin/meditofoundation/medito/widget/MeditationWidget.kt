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
import org.json.JSONArray
import java.util.Calendar

class MeditationWidget : GlanceAppWidget() {

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
        val streakCurrent = prefs.getInt("streak_current", 0)
        val totalTracksCompleted = prefs.getInt("total_tracks_completed", 0)
        val meditationDatesJson = prefs.getString("meditation_dates", "[]") ?: "[]"
        val freezeDatesJson = prefs.getString("freeze_dates", "[]") ?: "[]"
        val dayLabel = prefs.getString("day_label", "day") ?: "day"
        val daysLabel = prefs.getString("days_label", "days") ?: "days"
        // Use singular "day" if streak is 1, plural "days" otherwise
        val label = if (streakCurrent == 1) dayLabel else daysLabel

        val meditationDates = parseDateTimestamps(meditationDatesJson)
        val freezeDates = parseDateTimestamps(freezeDatesJson)
        val allActivityDates = (meditationDates + freezeDates).toSet()

        val today = Calendar.getInstance()
        today.set(Calendar.HOUR_OF_DAY, 0)
        today.set(Calendar.MINUTE, 0)
        today.set(Calendar.SECOND, 0)
        today.set(Calendar.MILLISECOND, 0)

        // Build calendar days - show last 7 days, newest first (today first)
        val allCalendarDays = mutableListOf<CalendarDay>()
        for (i in 0 until 7) {
            val day = Calendar.getInstance()
            day.timeInMillis = today.timeInMillis
            day.add(Calendar.DAY_OF_MONTH, -i)
            val dayOfWeek = day.get(Calendar.DAY_OF_WEEK)
            val dayAbbrev = getDayAbbreviation(dayOfWeek)
            val hasActivity = allActivityDates.contains(day.timeInMillis)
            allCalendarDays.add(CalendarDay(dayAbbrev, hasActivity))
        }

        // Always show 5 days - the flexible layout will spread them out when wide
        val daysToShow = 5
        val calendarDays = allCalendarDays.take(daysToShow).reversed() // Show newest days, oldest on left

        val hasActivityToday = allActivityDates.contains(today.timeInMillis)

        // Medito colors
        val backgroundColor = Color(0xFFF8F9FA) // lightBackground
        val accentColor = Color(0xffef5e55) // amber
        val textColor = Color(0xFF000000) // black
        val secondaryTextColor = Color(0xFF000000) // black
        val inactiveCircleColor = Color(0xFFE5E7EB) // lightGrey
        val checkmarkColor = Color(0xFF917DF0) // lightPurple

        val fireIconColor = if (hasActivityToday) checkmarkColor else inactiveCircleColor

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
                // Streak section - centered
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Vertical.CenterVertically,
                    horizontalAlignment = Alignment.Horizontal.CenterHorizontally
                ) {
                    Text(
                        text = "🔥",
                        style = TextStyle(
                            fontSize = 28.sp,
                            color = ColorProvider(fireIconColor)
                        ),
                        modifier = GlanceModifier.padding(end = 8.dp)
                    )
                    Text(
                        text = streakCurrent.toString(),
                        style = TextStyle(
                            fontSize = 36.sp,
                            fontWeight = FontWeight.Bold,
                            color = ColorProvider(textColor)
                        )
                    )
                    Spacer(modifier = GlanceModifier.width(6.dp))
                    Text(
                        text = label,
                        style = TextStyle(
                            fontSize = 20.sp,
                            color = ColorProvider(textColor)
                        )
                    )
                }

                Spacer(modifier = GlanceModifier.height(16.dp))

                // Calendar section - Duolingo style with circular indicators
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.Horizontal.CenterHorizontally
                ) {
                    calendarDays.forEach { day ->
                        Column(
                            modifier = GlanceModifier
                                .defaultWeight(),
                            horizontalAlignment = Alignment.Horizontal.CenterHorizontally
                        ) {
                            Text(
                                text = day.abbreviation,
                                style = TextStyle(
                                    fontSize = 11.sp,
                                    color = ColorProvider(secondaryTextColor)
                                )
                            )
                            Spacer(modifier = GlanceModifier.height(6.dp))
                            // Circular indicator (Duolingo style - using square as Glance doesn't support rounded corners)
                            Box(
                                modifier = GlanceModifier
                                    .width(28.dp)
                                    .height(28.dp)
                                    .background(
                                        if (day.hasActivity) checkmarkColor else inactiveCircleColor
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                if (day.hasActivity) {
                                    Text(
                                        text = "✓",
                                        style = TextStyle(
                                            fontSize = 16.sp,
                                            color = ColorProvider(Color.White),
                                            fontWeight = FontWeight.Bold
                                        )
                                    )
                                }
                            }
                        }
                    }
                }

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

    private fun parseDateTimestamps(jsonString: String): List<Long> {
        return try {
            val jsonArray = JSONArray(jsonString)
            val dates = mutableListOf<Long>()
            for (i in 0 until jsonArray.length()) {
                val timestamp = jsonArray.getLong(i)
                val calendar = Calendar.getInstance()
                calendar.timeInMillis = timestamp
                calendar.set(Calendar.HOUR_OF_DAY, 0)
                calendar.set(Calendar.MINUTE, 0)
                calendar.set(Calendar.SECOND, 0)
                calendar.set(Calendar.MILLISECOND, 0)
                dates.add(calendar.timeInMillis)
            }
            dates
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun getDayAbbreviation(dayOfWeek: Int): String {
        return when (dayOfWeek) {
            Calendar.SUNDAY -> "S"
            Calendar.MONDAY -> "M"
            Calendar.TUESDAY -> "T"
            Calendar.WEDNESDAY -> "W"
            Calendar.THURSDAY -> "T"
            Calendar.FRIDAY -> "F"
            Calendar.SATURDAY -> "S"
            else -> ""
        }
    }

    private data class CalendarDay(val abbreviation: String, val hasActivity: Boolean)
}
