package meditofoundation.medito.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import android.content.Intent
import android.net.Uri
import androidx.glance.GlanceId
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.appwidget.action.actionStartActivity
import es.antonborri.home_widget.HomeWidgetGlanceState
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import meditofoundation.medito.R

// Size thresholds — one per layout tier
private val TINY      = DpSize(80.dp,  50.dp)   // 1×1 / cramped 2×1
private val MEDIUM    = DpSize(155.dp, 50.dp)   // comfortable 3×1
private val SQUARE    = DpSize(150.dp, 140.dp)  // 2×2 / 3×2
private val WIDE      = DpSize(270.dp, 50.dp)   // 4×1
private val WIDE_TALL = DpSize(270.dp, 110.dp)  // 4×2 and larger

class UpNextWidget : GlanceAppWidget() {

    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override val sizeMode: SizeMode
        get() = SizeMode.Responsive(setOf(TINY, MEDIUM, SQUARE, WIDE, WIDE_TALL))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { WidgetContent(context) }
    }

    @Composable
    private fun WidgetContent(context: Context) {
        val prefs = currentState<HomeWidgetGlanceState>().preferences
        val title    = prefs.getString("up_next_title",      "") ?: ""
        val subtitle = prefs.getString("up_next_subtitle",   "") ?: ""
        val packTitle = prefs.getString("up_next_pack_title", "") ?: ""
        val trackId  = prefs.getString("up_next_track_id",   "") ?: ""
        val completed = prefs.getInt("up_next_completed", 0)
        val total = prefs.getInt("up_next_total", 0)
        val palette = WidgetPalette.resolve(context, prefs.getString("theme_preference", "system") ?: "system")

        // Matches the app's Home hero: "START HERE · Pack" before anything in the pack is
        // played, "CONTINUE · Pack" after. No eyebrow once the pack is finished.
        val eyebrow = when {
            title.isEmpty() -> ""
            packTitle.isEmpty() -> upNextLabel(completed)
            else -> "${upNextLabel(completed)} · $packTitle"
        }
        val progress = if (title.isNotEmpty() && total > 0) Progress(completed, total) else null

        val size = LocalSize.current
        val layout = when {
            size.width >= WIDE.width && size.height >= WIDE_TALL.height -> Layout.WIDE_TALL
            size.width >= WIDE.width   -> Layout.WIDE
            size.width >= SQUARE.width && size.height >= SQUARE.height -> Layout.SQUARE
            size.width >= MEDIUM.width -> Layout.MEDIUM
            else                       -> Layout.TINY
        }

        // Append source params so DeepLinkService can attribute the tap to the
        // home-screen widget for analytics. When trackId is empty we still fire
        // a deep link (no path) instead of launching MainActivity directly so
        // that the empty-state tap is also attributable.
        val tapUri = if (trackId.isNotEmpty()) {
            "org.meditofoundation://medito/tracks/$trackId?source=home_widget&widget=up_next"
        } else {
            "org.meditofoundation://medito/?source=home_widget&widget=up_next"
        }
        val tapAction = actionStartActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(tapUri))
                .apply {
                    setPackage(context.packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                },
        )

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(palette.background)
                .clickable(tapAction),
            contentAlignment = Alignment.Center,
        ) {
            when (layout) {
                Layout.TINY      -> TinyLayout(title, size, palette)
                Layout.MEDIUM    -> MediumLayout(title, eyebrow, size, palette)
                Layout.SQUARE    -> SquareLayout(title, upNextLabel(completed), progress, size, palette)
                Layout.WIDE      -> WideLayout(title, eyebrow, size, palette)
                Layout.WIDE_TALL -> WideTallLayout(title, subtitle, eyebrow, progress, size, palette)
            }
        }
    }

    // 1×1 / small 2×1 — play button + one line of title
    @Composable
    private fun TinyLayout(title: String, size: DpSize, palette: WidgetPalette) {
        Column(
            modifier = GlanceModifier.padding(10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            PlayButton(size = 40.dp, palette = palette)
            Spacer(modifier = GlanceModifier.height(6.dp))
            WidgetText(
                text = title.ifEmpty { "Medito" },
                fontSize = 12f,
                weight = WidgetWeight.SemiBold,
                color = palette.foreground,
                maxWidth = size.width - 20.dp,
                centered = true,
            )
        }
    }

    // Comfortable 3×1 — eyebrow over title, play button alongside
    @Composable
    private fun MediumLayout(title: String, eyebrow: String, size: DpSize, palette: WidgetPalette) {
        val textWidth = size.width - 24.dp - 8.dp - 36.dp
        Column(
            modifier = GlanceModifier
                .fillMaxWidth()
                .padding(12.dp),
        ) {
            Eyebrow(eyebrow, size.width - 24.dp, palette)
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.Vertical.CenterVertically,
            ) {
                // A weighted image would centre the bitmap; keep the title flush left.
                Box(modifier = GlanceModifier.defaultWeight(), contentAlignment = Alignment.CenterStart) {
                    WidgetText(
                        text = title.ifEmpty { EMPTY_TITLE },
                        fontSize = 16f,
                        weight = WidgetWeight.Bold,
                        color = palette.foreground,
                        maxWidth = textWidth,
                        maxLines = 2,
                        lineHeight = 1.05f,
                    )
                }
                Spacer(modifier = GlanceModifier.width(8.dp))
                PlayButton(size = 36.dp, palette = palette)
            }
        }
    }

    // 4×1 — text block on the left, play button on the right
    @Composable
    private fun WideLayout(title: String, eyebrow: String, size: DpSize, palette: WidgetPalette) {
        val textWidth = size.width - 32.dp - 14.dp - 44.dp
        Row(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            Column(modifier = GlanceModifier.defaultWeight()) {
                Eyebrow(eyebrow, textWidth, palette)
                WidgetText(
                    text = title.ifEmpty { EMPTY_TITLE },
                    fontSize = 18f,
                    weight = WidgetWeight.Bold,
                    color = palette.foreground,
                    maxWidth = textWidth,
                )
            }
            Spacer(modifier = GlanceModifier.width(14.dp))
            PlayButton(size = 44.dp, palette = palette)
        }
    }

    // 2×2 / 3×2 — label and play button along the top, title and progress along the bottom
    // (mirrors iOS small)
    @Composable
    private fun SquareLayout(title: String, label: String, progress: Progress?, size: DpSize, palette: WidgetPalette) {
        val contentWidth = size.width - 28.dp
        Column(modifier = GlanceModifier.fillMaxSize().padding(14.dp)) {
            TopRow(if (title.isEmpty()) "" else label, contentWidth - 40.dp - 8.dp, 40.dp, palette)
            Spacer(modifier = GlanceModifier.defaultWeight())
            WidgetText(
                text = title.ifEmpty { EMPTY_TITLE },
                fontSize = 18f,
                weight = WidgetWeight.Bold,
                color = palette.foreground,
                maxWidth = contentWidth,
                maxLines = 3,
                lineHeight = 1.05f,
            )
            if (progress != null) {
                Box(modifier = GlanceModifier.padding(top = 8.dp)) {
                    ProgressBar(fraction = progress.fraction, width = contentWidth, palette = palette)
                }
            }
        }
    }

    // 4×2 and larger — the same arrangement with room for the pack, subtitle and a "3/10"
    // count (mirrors iOS medium)
    @Composable
    private fun WideTallLayout(
        title: String,
        subtitle: String,
        eyebrow: String,
        progress: Progress?,
        size: DpSize,
        palette: WidgetPalette,
    ) {
        val contentWidth = size.width - 32.dp
        Column(modifier = GlanceModifier.fillMaxSize().padding(16.dp)) {
            TopRow(eyebrow, contentWidth - 44.dp - 12.dp, 44.dp, palette)
            Spacer(modifier = GlanceModifier.defaultWeight())
            WidgetText(
                text = title.ifEmpty { EMPTY_TITLE },
                fontSize = 22f,
                weight = WidgetWeight.Bold,
                color = palette.foreground,
                maxWidth = contentWidth,
                maxLines = 2,
                lineHeight = 1.05f,
            )
            if (title.isNotEmpty() && subtitle.isNotEmpty()) {
                WidgetText(
                    text = subtitle,
                    fontSize = 14f,
                    weight = WidgetWeight.Medium,
                    color = palette.muted,
                    maxWidth = contentWidth,
                    modifier = GlanceModifier.padding(top = 2.dp),
                )
            }
            if (progress != null) {
                Row(
                    modifier = GlanceModifier.padding(top = 10.dp),
                    verticalAlignment = Alignment.Vertical.CenterVertically,
                ) {
                    ProgressBar(fraction = progress.fraction, width = contentWidth - 44.dp, palette = palette)
                    Spacer(modifier = GlanceModifier.width(8.dp))
                    WidgetText(
                        text = "${progress.completed}/${progress.total}",
                        fontSize = 12f,
                        weight = WidgetWeight.SemiBold,
                        color = palette.muted,
                    )
                }
            }
        }
    }

    /** Eyebrow (or, once the pack is finished, a quiet tick) with the play button top-right. */
    @Composable
    private fun TopRow(eyebrow: String, eyebrowWidth: Dp, playSize: Dp, palette: WidgetPalette) {
        Row(modifier = GlanceModifier.fillMaxWidth()) {
            Box(modifier = GlanceModifier.defaultWeight().padding(top = 2.dp)) {
                if (eyebrow.isEmpty()) {
                    Box(modifier = GlanceModifier.size(20.dp), contentAlignment = Alignment.Center) {
                        Image(
                            provider = ImageProvider(R.drawable.widget_dot),
                            contentDescription = null,
                            colorFilter = ColorFilter.tint(ColorProvider(palette.muted)),
                            modifier = GlanceModifier.size(20.dp),
                        )
                        Image(
                            provider = ImageProvider(R.drawable.widget_check),
                            contentDescription = "Pack complete",
                            colorFilter = ColorFilter.tint(ColorProvider(palette.background)),
                            modifier = GlanceModifier.size(20.dp),
                        )
                    }
                } else {
                    WidgetText(
                        text = eyebrow,
                        fontSize = 12f,
                        weight = WidgetWeight.SemiBold,
                        color = palette.muted,
                        maxWidth = eyebrowWidth,
                        letterSpacing = 0.08f,
                    )
                }
            }
            PlayButton(size = playSize, palette = palette)
        }
    }

    private class Progress(val completed: Int, val total: Int) {
        val fraction get() = completed.toFloat() / total
    }

    /** "CONTINUE · Pack" in the hero eyebrow's voice: small, semibold, tracked, muted. */
    @Composable
    private fun Eyebrow(text: String, maxWidth: Dp, palette: WidgetPalette) {
        if (text.isEmpty()) return
        WidgetText(
            text = text,
            fontSize = 12f,
            weight = WidgetWeight.SemiBold,
            color = palette.muted,
            maxWidth = maxWidth,
            letterSpacing = 0.08f,
        )
        Spacer(modifier = GlanceModifier.height(4.dp))
    }

    private fun upNextLabel(completed: Int) = if (completed == 0) "START HERE" else "CONTINUE"

    private enum class Layout { TINY, MEDIUM, SQUARE, WIDE, WIDE_TALL }
}

/** Shown when the pinned pack is finished (the app clears the session). */
private const val EMPTY_TITLE = "Choose what's next"
