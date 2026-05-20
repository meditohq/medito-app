package meditofoundation.medito.widget

import android.content.Context
import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.content.Intent
import android.net.Uri
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
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
import androidx.glance.layout.width
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.glance.appwidget.action.actionStartActivity
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import meditofoundation.medito.MainActivity
import meditofoundation.medito.R

// Size thresholds — one per layout tier
private val TINY   = DpSize(80.dp,  50.dp)   // 1×1 / cramped 2×1
private val MEDIUM = DpSize(155.dp, 50.dp)   // comfortable 3×1
private val WIDE   = DpSize(270.dp, 50.dp)   // 4×1 and larger

class UpNextWidget : GlanceAppWidget() {

    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override val sizeMode: SizeMode
        get() = SizeMode.Responsive(setOf(TINY, MEDIUM, WIDE))

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
        val themePreference = prefs.getString("theme_preference", "system") ?: "system"

        val isDark = when (themePreference) {
            "light" -> false
            "dark"  -> true
            else    -> isDarkMode(context)
        }

        val colors = if (isDark) {
            ThemeColors(
                backgroundColor    = Color(0xFF121212),
                textColor          = Color(0xFFFFFFFF),
                secondaryTextColor = Color(0xFFB3B3B3),
                labelColor         = Color(0xFF808080),
            )
        } else {
            ThemeColors(
                backgroundColor    = Color(0xFFF8F9FA),
                textColor          = Color(0xFF000000),
                secondaryTextColor = Color(0xFF666666),
                labelColor         = Color(0xFF999999),
            )
        }

        val width = LocalSizeCompat.current.width
        val layout = when {
            width >= WIDE.width   -> Layout.WIDE
            width >= MEDIUM.width -> Layout.MEDIUM
            else                  -> Layout.TINY
        }

        val tapAction = if (trackId.isNotEmpty()) {
            actionStartActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse("org.meditofoundation://medito/tracks/$trackId"))
                    .apply {
                        setPackage(context.packageName)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    },
            )
        } else {
            actionStartActivity(Intent(context, MainActivity::class.java))
        }

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(colors.backgroundColor)
                .clickable(tapAction),
            contentAlignment = Alignment.Center,
        ) {
            when (layout) {
                Layout.TINY   -> TinyLayout(title, colors)
                Layout.MEDIUM -> MediumLayout(title, packTitle, colors)
                Layout.WIDE   -> WideLayout(title, subtitle, packTitle, colors)
            }
        }
    }

    // 1×1 / small 2×1 — play circle + one line of title
    @Composable
    private fun TinyLayout(title: String, colors: ThemeColors) {
        Column(
            modifier = GlanceModifier.padding(10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Image(
                provider = ImageProvider(R.drawable.ic_play_circle_purple),
                contentDescription = "Play",
                modifier = GlanceModifier.width(44.dp).height(44.dp),
            )
            Spacer(modifier = GlanceModifier.height(6.dp))
            Text(
                text = if (title.isEmpty()) "Up next" else title,
                style = TextStyle(
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = ColorProvider(colors.textColor),
                ),
                maxLines = 1,
            )
        }
    }

    // Comfortable 3×1 — label row + title + play button side-by-side
    @Composable
    private fun MediumLayout(title: String, packTitle: String, colors: ThemeColors) {
        Column(
            modifier = GlanceModifier
                .fillMaxWidth()
                .padding(12.dp),
        ) {
            LabelRow(packTitle, 9.sp.value, colors)
            Spacer(modifier = GlanceModifier.height(4.dp))
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.Vertical.CenterVertically,
            ) {
                Text(
                    text = if (title.isEmpty()) "No session up next" else title,
                    style = TextStyle(
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(colors.textColor),
                    ),
                    maxLines = 2,
                    modifier = GlanceModifier.defaultWeight(),
                )
                Spacer(modifier = GlanceModifier.width(8.dp))
                Image(
                    provider = ImageProvider(R.drawable.ic_play_circle_purple),
                    contentDescription = "Play",
                    modifier = GlanceModifier.width(36.dp).height(36.dp),
                )
            }
        }
    }

    // 4×1 and larger — two columns: text block on left, play button on right
    @Composable
    private fun WideLayout(
        title: String,
        subtitle: String,
        packTitle: String,
        colors: ThemeColors,
    ) {
        Row(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            Column(modifier = GlanceModifier.defaultWeight()) {
                LabelRow(packTitle, 10.sp.value, colors)
                Spacer(modifier = GlanceModifier.height(5.dp))
                Text(
                    text = if (title.isEmpty()) "No session up next" else title,
                    style = TextStyle(
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(colors.textColor),
                    ),
                    maxLines = 2,
                )
                if (subtitle.isNotEmpty()) {
                    Spacer(modifier = GlanceModifier.height(3.dp))
                    Text(
                        text = subtitle,
                        style = TextStyle(
                            fontSize = 12.sp,
                            color = ColorProvider(colors.secondaryTextColor),
                        ),
                        maxLines = 1,
                    )
                }
            }
            Spacer(modifier = GlanceModifier.width(14.dp))
            Image(
                provider = ImageProvider(R.drawable.ic_play_circle_purple),
                contentDescription = "Play",
                modifier = GlanceModifier.width(48.dp).height(48.dp),
            )
        }
    }

    @Composable
    private fun LabelRow(packTitle: String, fontSize: Float, colors: ThemeColors) {
        Row(verticalAlignment = Alignment.Vertical.CenterVertically) {
            Text(
                text = "UP NEXT",
                style = TextStyle(
                    fontSize = fontSize.sp,
                    fontWeight = FontWeight.Medium,
                    color = ColorProvider(colors.labelColor),
                ),
            )
            if (packTitle.isNotEmpty()) {
                Spacer(modifier = GlanceModifier.width(4.dp))
                Text(
                    text = "· $packTitle",
                    style = TextStyle(
                        fontSize = fontSize.sp,
                        fontWeight = FontWeight.Medium,
                        color = ColorProvider(Color(0xFF917DF0)),
                    ),
                )
            }
        }
    }

    private fun isDarkMode(context: Context): Boolean {
        val nightModeFlags =
            context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return nightModeFlags == Configuration.UI_MODE_NIGHT_YES
    }

    private data class ThemeColors(
        val backgroundColor: Color,
        val textColor: Color,
        val secondaryTextColor: Color,
        val labelColor: Color,
    )

    private enum class Layout { TINY, MEDIUM, WIDE }
}

private object LocalSizeCompat {
    val current: DpSize
        @Composable get() = androidx.glance.LocalSize.current
}
