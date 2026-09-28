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

class ConsistencyWidget : GlanceAppWidget() {

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

        // Raw (not truncated) timestamps so the score and the strip can bucket
        // by the day-boundary offset themselves — truncating to midnight here
        // would lose the sub-day info the offset needs.
        val meditationRaw = parseRawTimestamps(meditationDatesJson)
        val freezeRaw = parseRawTimestamps(freezeDatesJson)

        // Computed on-device (not read from the cached "consistency_score" pref) so the
        // percentage stays live between app opens instead of only updating when Dart
        // last pushed a snapshot. Honour the day-boundary offset so the score and the
        // strip bucket days the same way the streak does (StreakCalculator) — otherwise
        // they disagree for users with a nonzero offset.
        val dayBoundaryOffsetHours = prefs.getInt("day_boundary_offset_hours", 0)
        val zone = ZoneId.systemDefault()
        fun bucketDay(millis: Long): LocalDate =
            Instant.ofEpochMilli(millis)
                .minusSeconds(dayBoundaryOffsetHours * 3600L)
                .atZone(zone)
                .toLocalDate()

        val consistencyToday = bucketDay(System.currentTimeMillis())
        val consistencyScore = ConsistencyScoreCalculator.calculate(
            meditationRaw,
            freezeRaw,
            today = consistencyToday,
            zone = zone,
            dayBoundaryOffsetHours = dayBoundaryOffsetHours,
        )

        val activityDays = (meditationRaw + freezeRaw).map(::bucketDay).toSet()

        val themePreference = prefs.getString("theme_preference", "system") ?: "system"

        StatWidgetContent(
            context = context,
            value = "$consistencyScore%",
            unit = "",
            ringScore = consistencyScore,
            doneToday = activityDays.contains(consistencyToday),
            today = consistencyToday,
            activityDays = activityDays,
            palette = WidgetPalette.resolve(context, themePreference),
            tapUri = "org.meditofoundation://medito/?source=home_widget&widget=consistency",
        )
    }

    // Raw timestamps (not truncated to midnight) so the score and the calendar
    // strip can bucket days by the day-boundary offset themselves.
    private fun parseRawTimestamps(jsonString: String): List<Long> {
        return try {
            val jsonArray = JSONArray(jsonString)
            (0 until jsonArray.length()).map { jsonArray.getLong(it) }
        } catch (e: Exception) {
            emptyList()
        }
    }
}
