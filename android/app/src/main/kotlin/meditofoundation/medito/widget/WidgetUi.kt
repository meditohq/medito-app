package meditofoundation.medito.widget

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.glance.ColorFilter
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.size
import androidx.glance.unit.ColorProvider
import meditofoundation.medito.R
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.ceil
import kotlin.math.min

/**
 * The app's monochrome palette (lib/constants/colors/color_constants.dart): near-black page
 * and off-white text in dark mode, white page and near-black text in light mode. The accent is
 * the theme's inverted "primary" (light on dark, dark on light), with [onAccent] for glyphs on it.
 */
internal data class WidgetPalette(
    val background: Color,
    val foreground: Color,
    val muted: Color,
    val inactive: Color,
    val accent: Color,
    val onAccent: Color,
) {
    companion object {
        private val dark = WidgetPalette(
            background = Color(0xFF1A1A1A), // ebony
            foreground = Color(0xFFFFFFFF),
            muted = Color(0xFFA1A1A1), // graphite
            inactive = Color(0xFF333333), // charcoal
            accent = Color(0xFFE5E5E5), // brandPurple (dark)
            onAccent = Color(0xFF171717), // onAccentDark
        )

        private val light = WidgetPalette(
            background = Color(0xFFFFFFFF), // lightBackground
            foreground = Color(0xFF0A0A0A), // lightOnSurface
            muted = Color(0xFF737373), // lightSecondary
            inactive = Color(0xFFE5E5E5), // lightGrey
            accent = Color(0xFF171717), // brandPurple (light)
            onAccent = Color(0xFFFAFAFA), // onAccentLight
        )

        /** Honours the in-app theme choice, falling back to the system setting. */
        fun resolve(context: Context, themePreference: String): WidgetPalette = when (themePreference) {
            "light" -> light
            "dark" -> dark
            else -> {
                val night = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                if (night == Configuration.UI_MODE_NIGHT_YES) dark else light
            }
        }
    }
}

internal enum class WidgetWeight(val fileSuffix: String, val value: Int) {
    Regular("Regular", 400),
    Medium("Medium", 500),
    SemiBold("SemiBold", 600),
    Bold("Bold", 700),
}

/**
 * Google Sans, read from the Flutter bundle so the widgets share the app's font files instead of
 * shipping a second copy. Falls back to the system sans if the asset can't be opened.
 */
internal object WidgetFonts {
    private const val ASSET_DIR = "flutter_assets/assets/fonts/google-sans"
    private val cache = ConcurrentHashMap<WidgetWeight, Typeface>()

    fun typeface(context: Context, weight: WidgetWeight): Typeface = cache.getOrPut(weight) {
        try {
            Typeface.createFromAsset(context.assets, "$ASSET_DIR/GoogleSans-${weight.fileSuffix}.ttf")
        } catch (e: RuntimeException) {
            if (Build.VERSION.SDK_INT >= 28) {
                Typeface.create(Typeface.DEFAULT, weight.value, false)
            } else if (weight.value >= 600) {
                Typeface.DEFAULT_BOLD
            } else {
                Typeface.DEFAULT
            }
        }
    }
}

/**
 * Text in Google Sans. RemoteViews can't take a bundled typeface, so the text is laid out with
 * [StaticLayout] and drawn into an alpha-only bitmap, which the image tint then colours. Sizes are
 * in sp, so the system font scale still applies.
 *
 * [maxWidth] bounds the line; longer text wraps up to [maxLines] and then ellipsizes.
 */
@Composable
internal fun WidgetText(
    text: String,
    fontSize: Float,
    weight: WidgetWeight,
    color: Color,
    modifier: GlanceModifier = GlanceModifier,
    maxWidth: Dp = Dp.Unspecified,
    maxLines: Int = 1,
    letterSpacing: Float = 0f,
    lineHeight: Float = 1.2f,
    centered: Boolean = false,
) {
    if (text.isEmpty()) return
    val context = LocalContext.current
    val metrics = context.resources.displayMetrics
    val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = WidgetFonts.typeface(context, weight)
        textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, fontSize, metrics)
        this.letterSpacing = letterSpacing
        fontFeatureSettings = "tnum"
    }
    val limit = if (maxWidth == Dp.Unspecified) Int.MAX_VALUE else (maxWidth.value * metrics.density).toInt()
    val width = min(ceil(Layout.getDesiredWidth(text, paint)).toInt(), limit).coerceAtLeast(1)
    val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
        .setAlignment(if (centered) Layout.Alignment.ALIGN_CENTER else Layout.Alignment.ALIGN_NORMAL)
        .setIncludePad(false)
        .setLineSpacing(0f, lineHeight)
        .setMaxLines(maxLines)
        .setEllipsize(TextUtils.TruncateAt.END)
        .build()
    val bitmap = Bitmap.createBitmap(width, layout.height.coerceAtLeast(1), Bitmap.Config.ALPHA_8).apply {
        density = metrics.densityDpi
    }
    layout.draw(Canvas(bitmap))
    Image(
        provider = ImageProvider(bitmap),
        contentDescription = text,
        colorFilter = ColorFilter.tint(ColorProvider(color)),
        modifier = modifier,
    )
}

/** A day in the streak strip: an accent disc with a check when practised, a quiet disc if not. */
@Composable
internal fun DayDot(active: Boolean, size: Dp, palette: WidgetPalette) {
    Box(modifier = GlanceModifier.size(size), contentAlignment = Alignment.Center) {
        Image(
            provider = ImageProvider(R.drawable.widget_dot),
            contentDescription = if (active) "Completed day" else "Empty day",
            colorFilter = ColorFilter.tint(ColorProvider(if (active) palette.accent else palette.inactive)),
            modifier = GlanceModifier.size(size),
        )
        if (active) {
            Image(
                provider = ImageProvider(R.drawable.widget_check),
                contentDescription = null,
                colorFilter = ColorFilter.tint(ColorProvider(palette.onAccent)),
                modifier = GlanceModifier.size(size),
            )
        }
    }
}

/** The app's play button: accent disc, rounded play glyph in [WidgetPalette.onAccent]. */
@Composable
internal fun PlayButton(size: Dp, palette: WidgetPalette) {
    Box(modifier = GlanceModifier.size(size), contentAlignment = Alignment.Center) {
        Image(
            provider = ImageProvider(R.drawable.widget_dot),
            contentDescription = "Play",
            colorFilter = ColorFilter.tint(ColorProvider(palette.accent)),
            modifier = GlanceModifier.size(size),
        )
        Image(
            provider = ImageProvider(R.drawable.ic_play),
            contentDescription = null,
            colorFilter = ColorFilter.tint(ColorProvider(palette.onAccent)),
            modifier = GlanceModifier.size(size * 0.5f),
        )
    }
}

/** Thin rounded pack-progress bar, as under the Home hero title. */
@Composable
internal fun ProgressBar(fraction: Float, width: Dp, palette: WidgetPalette, height: Dp = 4.dp) {
    val metrics = LocalContext.current.resources.displayMetrics
    val w = (width.value * metrics.density).toInt().coerceAtLeast(1)
    val h = (height.value * metrics.density).toInt().coerceAtLeast(1)
    val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).apply { density = metrics.densityDpi }
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    val radius = h / 2f
    paint.color = palette.foreground.copy(alpha = 0.15f).toArgb()
    canvas.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), radius, radius, paint)
    val filled = w * fraction.coerceIn(0f, 1f)
    if (filled > 0f) {
        paint.color = palette.accent.toArgb()
        canvas.drawRoundRect(RectF(0f, 0f, filled.coerceAtLeast(h.toFloat()), h.toFloat()), radius, radius, paint)
    }
    Image(provider = ImageProvider(bitmap), contentDescription = null)
}

/**
 * The in-app consistency chip's ring: the score as an arc over a quiet track. Drawn as two
 * alpha masks so each can take its palette tint.
 */
@Composable
internal fun ConsistencyRing(score: Int, size: Dp, color: Color, palette: WidgetPalette) {
    val metrics = LocalContext.current.resources.displayMetrics
    val px = (size.value * metrics.density).toInt().coerceAtLeast(1)
    val stroke = px * 0.12f
    fun arc(sweep: Float): Bitmap {
        val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ALPHA_8).apply { density = metrics.densityDpi }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        val inset = stroke / 2
        Canvas(bitmap).drawArc(RectF(inset, inset, px - inset, px - inset), -90f, sweep, false, paint)
        return bitmap
    }
    Box(modifier = GlanceModifier.size(size), contentAlignment = Alignment.Center) {
        Image(
            provider = ImageProvider(arc(360f)),
            contentDescription = "$score%",
            colorFilter = ColorFilter.tint(ColorProvider(palette.inactive)),
        )
        if (score > 0) {
            Image(
                provider = ImageProvider(arc(360f * score.coerceAtMost(100) / 100)),
                contentDescription = null,
                colorFilter = ColorFilter.tint(ColorProvider(color)),
            )
        }
    }
}
