package meditofoundation.medito.widget

import android.content.Context
import android.content.res.Configuration
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.Dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
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
import androidx.glance.appwidget.cornerRadius
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import meditofoundation.medito.R
import android.content.Intent
import android.net.Uri
import androidx.glance.appwidget.action.actionStartActivity
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
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

        // Tap fires a deep link with source params so DeepLinkService can log
        // the widget tap analytics. No path segments → app just opens.
        val tapAction = actionStartActivity(
            Intent(
                Intent.ACTION_VIEW,
                Uri.parse("org.meditofoundation://medito/?source=home_widget&widget=streak"),
            ).apply {
                setPackage(context.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(backgroundColor)
                .padding(8.dp)
                .clickable(onClick = tapAction)
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
                    Image(
                        provider = ImageProvider(
                            if (hasActivityToday) R.drawable.ic_fire_purple else R.drawable.ic_fire_grey
                        ),
                        contentDescription = "Fire icon",
                        modifier = GlanceModifier
                            .width(24.dp)
                            .height(24.dp)
                            .padding(top = 2.dp, end = 4.dp)
                    )
                    Text(
                        text = streakCurrent.toString(),
                        style = TextStyle(
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold,
                            color = ColorProvider(textColor)
                        )
                    )
                    Spacer(modifier = GlanceModifier.width(2.dp))
                    Text(
                        text = label,
                        style = TextStyle(
                            fontSize = 14.sp,
                            color = ColorProvider(textColor)
                        )
                    )
                }

                Spacer(modifier = GlanceModifier.height(4.dp))

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
                                    fontSize = 9.sp,
                                    color = ColorProvider(secondaryTextColor)
                                )
                            )
                            Spacer(modifier = GlanceModifier.height(2.dp))
                            Image(
                                provider = ImageProvider(
                                    if (day.hasActivity) R.drawable.streak_day_checked_purple else R.drawable.streak_day_unchecked
                                ),
                                contentDescription = if (day.hasActivity) "Completed day" else "Empty day",
                                modifier = GlanceModifier
                                    .width(20.dp)
                                    .height(20.dp)
                            )
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

    @Composable
    fun GlanceModifier.appWidgetInnerCornerRadius(widgetPadding: Dp): GlanceModifier {
        if (Build.VERSION.SDK_INT < 31) {
            return this
        }
        val resources = LocalContext.current.resources
        val px = resources.getDimension(android.R.dimen.system_app_widget_background_radius)
        val widgetBackgroundRadiusDpValue = px / resources.displayMetrics.density
        if (widgetBackgroundRadiusDpValue < widgetPadding.value.toFloat()) {
            return this
        }
        return this.cornerRadius(Dp(widgetBackgroundRadiusDpValue - widgetPadding.value))
    }
}
