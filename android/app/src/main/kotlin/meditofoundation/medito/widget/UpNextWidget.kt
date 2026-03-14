package meditofoundation.medito.widget

import android.content.Context
import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
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
import androidx.glance.layout.width
import androidx.glance.layout.wrapContentHeight
import androidx.glance.layout.wrapContentWidth
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
import meditofoundation.medito.MainActivity
import meditofoundation.medito.R

private val NARROW = DpSize(140.dp, 50.dp)
private val WIDE = DpSize(280.dp, 50.dp)

class UpNextWidget : GlanceAppWidget() {

    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()

    override val sizeMode: SizeMode
        get() = SizeMode.Responsive(setOf(NARROW, WIDE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            WidgetContent(context)
        }
    }

    @Composable
    private fun WidgetContent(context: Context) {
        val prefs = currentState<HomeWidgetGlanceState>().preferences
        val title = prefs.getString("up_next_title", "") ?: ""
        val subtitle = prefs.getString("up_next_subtitle", "") ?: ""
        val packTitle = prefs.getString("up_next_pack_title", "") ?: ""
        val completed = prefs.getInt("up_next_completed", 0)
        val total = prefs.getInt("up_next_total", 0)
        val themePreference = prefs.getString("theme_preference", "system") ?: "system"

        val isDarkMode = when (themePreference) {
            "light" -> false
            "dark" -> true
            "system" -> isDarkMode(context)
            else -> isDarkMode(context)
        }

        val colors = if (isDarkMode) {
            ThemeColors(
                backgroundColor = Color(0xFF121212),
                textColor = Color(0xFFFFFFFF),
                secondaryTextColor = Color(0xFFB3B3B3),
                labelColor = Color(0xFF808080),
            )
        } else {
            ThemeColors(
                backgroundColor = Color(0xFFF8F9FA),
                textColor = Color(0xFF000000),
                secondaryTextColor = Color(0xFF666666),
                labelColor = Color(0xFF999999),
            )
        }

        val isWide = LocalSizeCompat.current.width >= WIDE.width

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(colors.backgroundColor)
                .padding(12.dp)
                .clickable(onClick = actionStartActivity<MainActivity>(context)),
        ) {
            if (isWide) {
                WideLayout(title, subtitle, packTitle, completed, total, colors)
            } else {
                NarrowLayout(title, packTitle, completed, total, colors)
            }
        }
    }

    @Composable
    private fun NarrowLayout(
        title: String,
        packTitle: String,
        completed: Int,
        total: Int,
        colors: ThemeColors,
    ) {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Row(verticalAlignment = Alignment.Vertical.CenterVertically) {
                Text(
                    text = "UP NEXT",
                    style = TextStyle(
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Medium,
                        color = ColorProvider(colors.labelColor),
                    ),
                )
                if (packTitle.isNotEmpty()) {
                    Spacer(modifier = GlanceModifier.width(4.dp))
                    Text(
                        text = "· $packTitle",
                        style = TextStyle(
                            fontSize = 9.sp,
                            fontWeight = FontWeight.Medium,
                            color = ColorProvider(Color(0xFF917DF0)),
                        ),
                    )
                }
            }

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

            if (total > 0) {
                Spacer(modifier = GlanceModifier.height(2.dp))
                Text(
                    text = "$completed of $total",
                    style = TextStyle(
                        fontSize = 9.sp,
                        color = ColorProvider(colors.secondaryTextColor),
                    ),
                )
            }
        }
    }

    @Composable
    private fun WideLayout(
        title: String,
        subtitle: String,
        packTitle: String,
        completed: Int,
        total: Int,
        colors: ThemeColors,
    ) {
        Row(
            modifier = GlanceModifier.fillMaxSize(),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            Column(modifier = GlanceModifier.defaultWeight().fillMaxHeight()) {
                Row(verticalAlignment = Alignment.Vertical.CenterVertically) {
                    Text(
                        text = "UP NEXT",
                        style = TextStyle(
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Medium,
                            color = ColorProvider(colors.labelColor),
                        ),
                    )
                    if (packTitle.isNotEmpty()) {
                        Spacer(modifier = GlanceModifier.width(4.dp))
                        Text(
                            text = "· $packTitle",
                            style = TextStyle(
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Medium,
                                color = ColorProvider(Color(0xFF917DF0)),
                            ),
                        )
                    }
                }

                Spacer(modifier = GlanceModifier.height(4.dp))

                Text(
                    text = if (title.isEmpty()) "No session up next" else title,
                    style = TextStyle(
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(colors.textColor),
                    ),
                    maxLines = 2,
                )

                if (subtitle.isNotEmpty()) {
                    Spacer(modifier = GlanceModifier.height(2.dp))
                    Text(
                        text = subtitle,
                        style = TextStyle(
                            fontSize = 12.sp,
                            color = ColorProvider(colors.secondaryTextColor),
                        ),
                        maxLines = 1,
                    )
                }

                Spacer(modifier = GlanceModifier.defaultWeight())

                if (total > 0) {
                    Text(
                        text = "$completed of $total sessions",
                        style = TextStyle(
                            fontSize = 10.sp,
                            color = ColorProvider(colors.secondaryTextColor),
                        ),
                    )
                }
            }

            Spacer(modifier = GlanceModifier.width(12.dp))

            Image(
                provider = ImageProvider(R.drawable.ic_play_circle_purple),
                contentDescription = "Play",
                modifier = GlanceModifier.width(44.dp).height(44.dp),
            )
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
}

// Glance 1.1+ exposes LocalSize via androidx.glance.LocalSize; this compat wrapper
// reads the same ambient so the code compiles across Glance versions.
private object LocalSizeCompat {
    val current: DpSize
        @Composable get() = androidx.glance.LocalSize.current
}
