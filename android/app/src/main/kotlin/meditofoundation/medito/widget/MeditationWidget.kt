package meditofoundation.medito.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.glance.GlanceId
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.currentState
import androidx.glance.state.GlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import org.json.JSONArray
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class MeditationWidget : GlanceAppWidget() {

    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override val sizeMode: SizeMode
        get() = statSizeMode

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            WidgetContent(context)
        }
    }

    @Composable
    private fun WidgetContent(context: Context) {
        val prefs = currentState<HomeWidgetGlanceState>().preferences
        val totalTracksCompleted = prefs.getInt("total_tracks_completed", 0)
        val meditationDatesJson = prefs.getString("meditation_dates", "[]") ?: "[]"
        val freezeDatesJson = prefs.getString("freeze_dates", "[]") ?: "[]"
        val dayBoundaryOffsetHours = prefs.getInt("day_boundary_offset_hours", 0)
        val dayLabel = prefs.getString("day_label", "day") ?: "day"
        val daysLabel = prefs.getString("days_label", "days") ?: "days"

        // Raw (not truncated) timestamps so the streak, strip, and flame all
        // bucket days by the day-boundary offset — truncating to midnight here
        // would lose the sub-day info the offset needs, leaving the dots/flame
        // on the old plain-local behaviour while the streak number is offset-aware.
        val meditationRaw = parseRawTimestamps(meditationDatesJson)
        val freezeRaw = parseRawTimestamps(freezeDatesJson)

        // Computed on-device (not read from the cached "streak_current" pref) so
        // the streak stays live between app opens instead of only updating when
        // Dart last pushed a snapshot.
        val streakCurrent = StreakCalculator.calculate(
            meditationRaw,
            freezeRaw,
            dayBoundaryOffsetHours,
        )
        // Use singular "day" if streak is 1, plural "days" otherwise
        val label = if (streakCurrent == 1) dayLabel else daysLabel

        // Bucket activity into logical days using the same day-boundary offset,
        // so the strip and flame agree with the streak number.
        val zone = ZoneId.systemDefault()
        fun bucketDay(millis: Long): LocalDate =
            Instant.ofEpochMilli(millis)
                .minusSeconds(dayBoundaryOffsetHours * 3600L)
                .atZone(zone)
                .toLocalDate()
        val activityDays = (meditationRaw + freezeRaw).map(::bucketDay).toSet()
        val today = bucketDay(System.currentTimeMillis())

        val themePreference = prefs.getString("theme_preference", "system") ?: "system"

        StatWidgetContent(
            context = context,
            value = streakCurrent.toString(),
            unit = label,
            doneToday = activityDays.contains(today),
            today = today,
            activityDays = activityDays,
            palette = WidgetPalette.resolve(context, themePreference),
            tapUri = "org.meditofoundation://medito/?source=home_widget&widget=streak",
        )
    }

    // Raw timestamps (not truncated to midnight) so the streak, strip, and
    // flame can all bucket days by the day-boundary offset themselves.
    private fun parseRawTimestamps(jsonString: String): List<Long> {
        return try {
            val jsonArray = JSONArray(jsonString)
            (0 until jsonArray.length()).map { jsonArray.getLong(it) }
        } catch (e: Exception) {
            emptyList()
        }
    }
}
