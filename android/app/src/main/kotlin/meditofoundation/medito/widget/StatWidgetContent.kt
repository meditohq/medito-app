package meditofoundation.medito.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.unit.ColorProvider
import meditofoundation.medito.R
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

/** Localised one-letter weekday ("M", "T"…). */
internal fun weekdayLetter(date: LocalDate): String =
    date.dayOfWeek.getDisplayName(TextStyle.NARROW_STANDALONE, Locale.getDefault())

private val STAT_COMPACT = DpSize(110.dp, 50.dp)  // 2×1
private val STAT_TALL = DpSize(150.dp, 160.dp)    // 2×2
private val STAT_WIDE = DpSize(280.dp, 140.dp)    // short 4×2
private val STAT_WIDE_TALL = DpSize(280.dp, 180.dp) // 4×2 and up: room for bigger dots

internal val statSizeMode = SizeMode.Responsive(setOf(STAT_COMPACT, STAT_TALL, STAT_WIDE, STAT_WIDE_TALL))

/**
 * Shared body of the Streak and Consistency widgets. Mirrors the in-app streak chip: once today
 * is practised the icon lights up in the accent and the figure goes bold; before that both stay
 * quiet. The icon is a flame for the streak and, given a [ringScore], the consistency ring.
 *
 * - Compact (2×1): icon + figure over the last five days.
 * - Tall (2×2): figure up top, the last four weeks as a calendar below.
 * - Wide (4×2+): figure on the left, the last five weeks on the right.
 *
 * [unit] may be empty (e.g. "62%").
 */
@Composable
internal fun StatWidgetContent(
    context: Context,
    value: String,
    unit: String,
    ringScore: Int? = null,
    doneToday: Boolean,
    today: LocalDate,
    activityDays: Set<LocalDate>,
    palette: WidgetPalette,
    tapUri: String,
) {
    // Tap fires a deep link with source params so DeepLinkService can log the widget tap
    // analytics. No path segments → app just opens.
    val tapAction = actionStartActivity(
        Intent(Intent.ACTION_VIEW, Uri.parse(tapUri)).apply {
            setPackage(context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        },
    )
    val size = LocalSize.current
    val stat = StatParts(value, unit, ringScore, doneToday, palette)

    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(palette.background)
            .clickable(onClick = tapAction),
        contentAlignment = Alignment.Center,
    ) {
        when {
            size.width >= STAT_WIDE.width && size.height >= STAT_WIDE.height -> Row(
                modifier = GlanceModifier.fillMaxSize().padding(16.dp),
                verticalAlignment = Alignment.Vertical.CenterVertically,
            ) {
                Column(modifier = GlanceModifier.defaultWeight().fillMaxHeight()) {
                    stat.Icon(28.dp)
                    Spacer(modifier = GlanceModifier.defaultWeight())
                    stat.Figure(if (size.height >= STAT_WIDE_TALL.height) 56f else 48f)
                    stat.Unit(16f)
                }
                Spacer(modifier = GlanceModifier.width(16.dp))
                val roomy = size.height >= STAT_WIDE_TALL.height
                ActivityGrid(
                    today, activityDays, weeks = 5,
                    dot = if (roomy) 18.dp else 14.dp,
                    gap = if (roomy) 10.dp else 8.dp,
                    palette = palette,
                )
            }

            size.height >= STAT_TALL.height -> Column(modifier = GlanceModifier.fillMaxSize().padding(14.dp)) {
                Row(verticalAlignment = Alignment.Vertical.CenterVertically) {
                    stat.Icon(24.dp)
                    Spacer(modifier = GlanceModifier.width(6.dp))
                    stat.Figure(32f)
                    if (unit.isNotEmpty()) {
                        Spacer(modifier = GlanceModifier.width(4.dp))
                        stat.Unit(14f)
                    }
                }
                Spacer(modifier = GlanceModifier.defaultWeight())
                ActivityGrid(today, activityDays, weeks = 4, dot = 14.dp, gap = null, palette = palette)
            }

            else -> Column(
                modifier = GlanceModifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
                horizontalAlignment = Alignment.Horizontal.CenterHorizontally,
            ) {
                Row(verticalAlignment = Alignment.Vertical.CenterVertically) {
                    stat.Icon(22.dp)
                    Spacer(modifier = GlanceModifier.width(4.dp))
                    stat.Figure(24f)
                    if (unit.isNotEmpty()) {
                        Spacer(modifier = GlanceModifier.width(4.dp))
                        stat.Unit(14f)
                    }
                }
                Spacer(modifier = GlanceModifier.height(4.dp))
                FiveDayStrip(today, activityDays, palette)
            }
        }
    }
}

private class StatParts(
    val value: String,
    val unit: String,
    val ringScore: Int?,
    val doneToday: Boolean,
    val palette: WidgetPalette,
) {
    private val iconColor = if (doneToday) palette.accent else palette.muted

    @Composable
    fun Icon(size: Dp) {
        if (ringScore != null) {
            ConsistencyRing(score = ringScore, size = size, color = iconColor, palette = palette)
        } else {
            Image(
                provider = ImageProvider(if (doneToday) R.drawable.widget_flame_filled else R.drawable.widget_flame),
                contentDescription = null,
                colorFilter = ColorFilter.tint(ColorProvider(iconColor)),
                modifier = GlanceModifier.size(size),
            )
        }
    }

    @Composable
    fun Figure(fontSize: Float) = WidgetText(
        text = value,
        fontSize = fontSize,
        weight = if (doneToday) WidgetWeight.Bold else WidgetWeight.Medium,
        color = palette.foreground,
        letterSpacing = -0.01f,
    )

    @Composable
    fun Unit(fontSize: Float) = WidgetText(
        text = unit,
        fontSize = fontSize,
        weight = WidgetWeight.Medium,
        color = palette.muted,
    )
}

/** The last five logical days as a row of discs, oldest first. */
@Composable
private fun FiveDayStrip(today: LocalDate, activityDays: Set<LocalDate>, palette: WidgetPalette) {
    Row(modifier = GlanceModifier.fillMaxWidth()) {
        (4 downTo 0).map { today.minusDays(it.toLong()) }.forEach { day ->
            Column(
                modifier = GlanceModifier.defaultWeight(),
                horizontalAlignment = Alignment.Horizontal.CenterHorizontally,
            ) {
                WidgetText(
                    text = weekdayLetter(day),
                    fontSize = 12f,
                    weight = WidgetWeight.SemiBold,
                    color = palette.muted,
                )
                Spacer(modifier = GlanceModifier.height(2.dp))
                DayDot(active = day in activityDays, size = 20.dp, palette = palette)
            }
        }
    }
}

/**
 * The last [weeks] weeks as a calendar: rows of seven days ending with today in the bottom-right
 * corner (the weekday header follows the window, like the strip, so the grid is always full).
 * Practised days are filled; today is ringed until it's done.
 *
 * With a [gap] the grid has a fixed width; without one it spreads across the available width.
 */
@Composable
private fun ActivityGrid(
    today: LocalDate,
    activityDays: Set<LocalDate>,
    weeks: Int,
    dot: Dp,
    gap: Dp?,
    palette: WidgetPalette,
) {
    val start = today.minusDays(7L * weeks - 1)
    val rowModifier = if (gap != null) GlanceModifier.width(dot * 7 + gap * 6) else GlanceModifier.fillMaxWidth()
    // Glance caps a Row/Column at ten children, so rows are spaced with padding, not Spacers.
    Column {
        Row(modifier = rowModifier) {
            (0 until 7).forEach { d ->
                Box(modifier = GlanceModifier.defaultWeight(), contentAlignment = Alignment.Center) {
                    WidgetText(
                        text = weekdayLetter(start.plusDays(d.toLong())),
                        fontSize = 11f,
                        weight = WidgetWeight.SemiBold,
                        color = palette.muted,
                    )
                }
            }
        }
        (0 until weeks).forEach { w ->
            Row(modifier = rowModifier.padding(top = dot * 0.4f)) {
                (0 until 7).forEach { d ->
                    val day = start.plusDays(7L * w + d)
                    Box(modifier = GlanceModifier.defaultWeight(), contentAlignment = Alignment.Center) {
                        val active = day in activityDays
                        Box(modifier = GlanceModifier.size(dot), contentAlignment = Alignment.Center) {
                            Image(
                                provider = ImageProvider(R.drawable.widget_dot),
                                contentDescription = null,
                                colorFilter = ColorFilter.tint(ColorProvider(if (active) palette.accent else palette.inactive)),
                                modifier = GlanceModifier.size(dot),
                            )
                            if (day == today && !active) {
                                Image(
                                    provider = ImageProvider(R.drawable.widget_ring),
                                    contentDescription = null,
                                    colorFilter = ColorFilter.tint(ColorProvider(palette.muted)),
                                    modifier = GlanceModifier.size(dot),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
