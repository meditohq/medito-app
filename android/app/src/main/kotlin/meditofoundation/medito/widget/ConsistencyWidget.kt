package meditofoundation.medito.widget

import android.content.Context
import android.content.res.Configuration
import android.os.Build
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
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import meditofoundation.medito.R
import es.antonborri.home_widget.actionStartActivity
import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
import meditofoundation.medito.MainActivity
import org.json.JSONArray
import java.util.Calendar

class ConsistencyWidget : GlanceAppWidget() {

    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override val sizeMode: SizeMode
        get() = SizeMode.Responsive

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            WidgetContent(context)
        }
    }

    @Composable
    private fun WidgetContent(context: Context) {
        val size = LocalSize.current
        val isCompact = size.height < 150.dp
        
        val prefs = currentState<HomeWidgetGlanceState>().preferences
        val consistencyScore = prefs.getInt("consistency_score", 0)
        val totalTracksCompleted = prefs.getInt("total_tracks_completed", 0)
        val meditationDatesJson = prefs.getString("meditation_dates", "[]") ?: "[]"
        val freezeDatesJson = prefs.getString("freeze_dates", "[]") ?: "[]"

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

        // Get theme-aware colors based on app theme preference
        val themePreference = prefs.getString("theme_preference", "system") ?: "system"
        val isDarkMode = when (themePreference) {
            "light" -> false
            "dark" -> true
            "system" -> isDarkMode(context)
            else -> isDarkMode(context)
        }
        
        val colors = if (isDarkMode) {
            ThemeColors(
                backgroundColor = Color(0xFF121212), // dark background
                textColor = Color(0xFFFFFFFF), // white text
                secondaryTextColor = Color(0xFFB3B3B3), // light grey text
                inactiveCircleColor = Color(0xFF2C2C2C), // dark grey
                checkmarkColor = Color(0xFF917DF0) // lightPurple
            )
        } else {
            ThemeColors(
                backgroundColor = Color(0xFFF8F9FA), // lightBackground
                textColor = Color(0xFF000000), // black
                secondaryTextColor = Color(0xFF000000), // black
                inactiveCircleColor = Color(0xFFE5E7EB), // lightGrey
                checkmarkColor = Color(0xFF917DF0) // lightPurple
            )
        }
        
        val backgroundColor = colors.backgroundColor
        val textColor = colors.textColor
        val secondaryTextColor = colors.secondaryTextColor
        val inactiveCircleColor = colors.inactiveCircleColor
        val checkmarkColor = colors.checkmarkColor

        val fireIconColor = if (hasActivityToday) checkmarkColor else inactiveCircleColor

        // Adjust sizes based on compact mode
        val padding = if (isCompact) 12.dp else 20.dp
        val iconSize = if (isCompact) 28.dp else 36.dp
        val scoreFontSize = if (isCompact) 28.sp else 36.sp
        val percentFontSize = if (isCompact) 16.sp else 20.sp
        val labelFontSize = if (isCompact) 11.sp else 14.sp
        val dayAbbrevFontSize = if (isCompact) 9.sp else 11.sp
        val circleSize = if (isCompact) 22.dp else 28.dp
        val checkmarkSize = if (isCompact) 12.dp else 16.dp
        val spacingAfterScore = if (isCompact) 4.dp else 8.dp
        val spacingAfterLabel = if (isCompact) 8.dp else 16.dp
        val spacingInCalendar = if (isCompact) 4.dp else 6.dp

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(backgroundColor)
                .padding(padding)
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
                    Image(
                        provider = ImageProvider(
                            if (hasActivityToday) R.drawable.ic_fire_purple else R.drawable.ic_fire_grey
                        ),
                        contentDescription = "Fire icon",
                        modifier = GlanceModifier
                            .width(iconSize)
                            .height(iconSize)
                            .padding(top = if (isCompact) 2.dp else 4.dp, end = if (isCompact) 6.dp else 8.dp)
                    )
                    Text(
                        text = consistencyScore.toString(),
                        style = TextStyle(
                            fontSize = scoreFontSize,
                            fontWeight = FontWeight.Bold,
                            color = ColorProvider(textColor)
                        )
                    )
                    Spacer(modifier = GlanceModifier.width(if (isCompact) 2.dp else 4.dp))
                    Text(
                        text = "%",
                        style = TextStyle(
                            fontSize = percentFontSize,
                            color = ColorProvider(textColor)
                        )
                    )
                }

                Spacer(modifier = GlanceModifier.height(spacingAfterScore))

                // Label
                Text(
                    text = "Consistency",
                    style = TextStyle(
                        fontSize = labelFontSize,
                        color = ColorProvider(secondaryTextColor)
                    )
                )

                Spacer(modifier = GlanceModifier.height(spacingAfterLabel))

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
                                    fontSize = dayAbbrevFontSize,
                                    color = ColorProvider(secondaryTextColor)
                                )
                            )
                            Spacer(modifier = GlanceModifier.height(spacingInCalendar))
                            Box(
                                modifier = GlanceModifier
                                    .width(circleSize)
                                    .height(circleSize)
                                    .background(
                                        if (day.hasActivity) checkmarkColor else inactiveCircleColor
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                if (day.hasActivity) {
                                    Image(
                                        provider = ImageProvider(R.drawable.ic_checkmark_white),
                                        contentDescription = "Checkmark",
                                        modifier = GlanceModifier
                                            .width(checkmarkSize)
                                            .height(checkmarkSize)
                                    )
                                } else {
                                    Image(
                                        provider = ImageProvider(R.drawable.ic_square_grey),
                                        contentDescription = "Empty day",
                                        modifier = GlanceModifier
                                            .width(checkmarkSize)
                                            .height(checkmarkSize)
                                    )
                                }
                            }
                        }
                    }
                }

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

    private data class ThemeColors(
        val backgroundColor: Color,
        val textColor: Color,
        val secondaryTextColor: Color,
        val inactiveCircleColor: Color,
        val checkmarkColor: Color
    )

    private fun isDarkMode(context: Context): Boolean {
        val nightModeFlags = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return nightModeFlags == Configuration.UI_MODE_NIGHT_YES
    }
}
