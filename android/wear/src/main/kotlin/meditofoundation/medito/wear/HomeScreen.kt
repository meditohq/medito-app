package meditofoundation.medito.wear

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.basicMarquee
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.ScalingLazyColumnDefaults
import androidx.wear.compose.foundation.lazy.ScalingLazyListAnchorType
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import coil3.compose.AsyncImage

@Composable
fun HomeScreen(
    state: WatchState,
    onPlay: (WatchTrack) -> Unit,
    onFavorites: () -> Unit,
    onDownloads: () -> Unit,
) {
    val listState = rememberScalingLazyListState(initialCenterItemIndex = 0)
    val stat = statKind(state)

    ScreenScaffold(scrollState = listState) {
        ScalingLazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            // Full-bleed hero from the very top, no edge shrinking.
            autoCentering = null,
            anchorType = ScalingLazyListAnchorType.ItemStart,
            scalingParams = ScalingLazyColumnDefaults.scalingParams(edgeScale = 1f, edgeAlpha = 1f),
            contentPadding = PaddingValues(bottom = 48.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val upNext = state.upNext
            if (upNext != null) {
                stat?.let { item { Box(Modifier.fillMaxWidth().padding(top = 16.dp), contentAlignment = Alignment.Center) { StatPill(it, onImage = false) } } }
                item { UpNextHero(upNext = upNext, onPlay = { onPlay(upNext.track) }) }
            } else if (stat != null) {
                item {
                    Box(Modifier.fillMaxWidth().padding(top = 36.dp), contentAlignment = Alignment.Center) {
                        StatPill(stat, onImage = false)
                    }
                }
            }

            if (state.synced) {
                item {
                    // Icon tiles, like the phone's Home shortcuts.
                    Row(
                        // Keep the shortcuts away from the round screen edges.
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 46.dp),
                        horizontalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        state.daily?.let { daily ->
                            ShortcutTile("Daily", R.drawable.ic_sun, Modifier.weight(1f)) { onPlay(daily) }
                        }
                        ShortcutTile("Favorites", R.drawable.ic_star, Modifier.weight(1f), onFavorites)
                    }
                }
            } else {
                item { EmptyState() }
            }
            item { Spacer(Modifier.height(24.dp)) }
            item {
                androidx.wear.compose.material3.Button(
                    onClick = onDownloads,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 36.dp),
                    colors = ButtonDefaults.filledTonalButtonColors(),
                    label = { Text("Downloads") },
                )
            }
        }
    }
}

sealed interface StatKind {
    data class Consistency(val percent: Int) : StatKind
    data class Streak(val days: Int) : StatKind
}

/** Consistency score, unless the phone's Home would show the streak. */
private fun statKind(state: WatchState): StatKind? = when {
    state.showStreak -> state.streak.takeIf { it > 0 }?.let { StatKind.Streak(it) }
    else -> state.consistency?.let { StatKind.Consistency(it) }
}

/**
 * The phone Home's stat pill: a ring filled to the consistency score and
 * "85%", or the app's flame and the streak length.
 */
@Composable
fun StatPill(kind: StatKind, onImage: Boolean, modifier: Modifier = Modifier) {
    val label = when (kind) {
        is StatKind.Consistency -> "Consistency score: ${kind.percent}%"
        is StatKind.Streak -> "${kind.days} day streak"
    }
    Row(
        modifier = modifier
            .clip(CircleShape)
            .background(if (onImage) Color.Black.copy(alpha = 0.55f) else Color.White.copy(alpha = 0.14f))
            .padding(horizontal = 10.dp, vertical = 5.dp)
            .semantics(mergeDescendants = true) { contentDescription = label },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        when (kind) {
            is StatKind.Consistency -> {
                val track = Color.White.copy(alpha = 0.2f)
                Canvas(Modifier.size(12.dp)) {
                    val stroke = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round)
                    drawArc(track, 0f, 360f, useCenter = false, style = stroke)
                    drawArc(Color.White, -90f, 360f * kind.percent / 100f, useCenter = false, style = stroke)
                }
                Text("${kind.percent}%", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            }
            is StatKind.Streak -> {
                Icon(painterResource(R.drawable.ic_flame), contentDescription = null, modifier = Modifier.size(14.dp))
                Text("${kind.days}", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

/**
 * The phone's Home hero in miniature: pack cover full-bleed from the top of
 * the screen, "CONTINUE · Pack" eyebrow, title, white play button and
 * progress, with the stat pill just under the time.
 */
@Composable
private fun UpNextHero(upNext: UpNext, onPlay: () -> Unit) {
    // Leave room for the shortcuts so the first screen doesn't feel crammed.
    val height = (LocalConfiguration.current.screenHeightDp * 0.36f).dp
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 24.dp, end = 24.dp)
            .height(height)
            .clip(RoundedCornerShape(28.dp))
            .background(Color.White.copy(alpha = 0.1f))
            .clickable(enabled = upNext.canPlay, onClick = onPlay),
    ) {
        AsyncImage(
            model = upNext.coverUrl,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.matchParentSize(),
        )
        // A light shade at the top so the time reads over bright art.
        Box(
            Modifier.matchParentSize().background(
                Brush.verticalGradient(0f to Color.Black.copy(alpha = 0.45f), 0.3f to Color.Transparent)
            )
        )
        // Dark enough under the text to read on busy cover art.
        Box(
            Modifier.matchParentSize().background(
                Brush.verticalGradient(
                    0.1f to Color.Transparent,
                    0.5f to Color.Black.copy(alpha = 0.6f),
                    1f to Color.Black.copy(alpha = 0.9f),
                )
            )
        )

        Box(
            Modifier
                .align(Alignment.CenterEnd)
                .padding(end = 18.dp)
                .size(34.dp)
                .clip(CircleShape)
                .background(Color.White),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                painterResource(R.drawable.ic_play),
                contentDescription = "Play",
                tint = Color.Black,
                modifier = Modifier.size(15.dp),
            )
        }

        Column(
            modifier = Modifier.align(Alignment.BottomStart).padding(start = 18.dp, end = 58.dp, bottom = 14.dp),
            verticalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Text(
                upNext.track.title,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                softWrap = true,
            )
            if (upNext.total > 0) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    ProgressBar(upNext.completed.toFloat() / upNext.total, Modifier.weight(1f))
                    Spacer(Modifier.width(6.dp))
                    // Same as the phone hero: sessions completed.
                    Text(
                        "${upNext.completed} of ${upNext.total}",
                        fontSize = 10.sp,
                        color = Color.White.copy(alpha = 0.85f),
                    )
                }
            }
        }
    }
}

@Composable
private fun ProgressBar(value: Float, modifier: Modifier = Modifier) {
    Canvas(modifier.height(3.dp)) {
        val y = size.height / 2
        drawLine(Color.White.copy(alpha = 0.3f), Offset(0f, y), Offset(size.width, y), size.height, StrokeCap.Round)
        val end = size.width * value.coerceIn(0f, 1f)
        if (end > 0f) drawLine(Color.White, Offset(0f, y), Offset(end, y), size.height, StrokeCap.Round)
    }
}

/** A phone Home shortcut: the app's own icon on a tile, label below. */
@Composable
private fun ShortcutTile(title: String, @DrawableRes icon: Int, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier = modifier.clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            Modifier.fillMaxWidth().height(40.dp).clip(RoundedCornerShape(15.dp))
                .background(Color.White.copy(alpha = 0.14f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(painterResource(icon), contentDescription = null, modifier = Modifier.size(21.dp))
        }
        Text(title, fontSize = 11.sp, maxLines = 1)
    }
}

@Composable
private fun EmptyState() {
    Column(
        modifier = Modifier.fillMaxWidth().padding(top = 48.dp, start = 24.dp, end = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            painterResource(R.drawable.ic_phone),
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.6f),
            modifier = Modifier.size(26.dp),
        )
        Text(
            "Open Medito on your phone to get started.",
            fontSize = 13.sp,
            textAlign = TextAlign.Center,
            color = Color.White.copy(alpha = 0.6f),
        )
    }
}
