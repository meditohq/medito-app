package meditofoundation.medito.wear

import androidx.compose.foundation.basicMarquee
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text

private enum class Filter { Packs, Tracks }

/**
 * Favourites from the phone, filtered to packs or tracks. A pack plays its
 * next unfinished session (resolved on the phone, like Continue).
 */
@Composable
fun FavoritesScreen(favorites: List<WatchTrack>, onPlay: (WatchTrack) -> Unit) {
    val hasPacks = favorites.any { it.packTitle.isNotEmpty() }
    val hasTracks = favorites.any { it.packTitle.isEmpty() }
    // Opens on packs (the first filter), unless there are only favourite tracks.
    var chosen by rememberSaveable { mutableStateOf<Filter?>(null) }
    val current = chosen ?: if (!hasPacks && hasTracks) Filter.Tracks else Filter.Packs
    val items = favorites.filter { (current == Filter.Packs) == it.packTitle.isNotEmpty() }

    val listState = rememberScalingLazyListState()
    ScreenScaffold(scrollState = listState) {
        ScalingLazyColumn(state = listState, modifier = Modifier.fillMaxSize()) {
            item { ListHeader { Text("Favorites") } }
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    FilterChip("Packs", current == Filter.Packs, Modifier.weight(1f)) { chosen = Filter.Packs }
                    FilterChip("Tracks", current == Filter.Tracks, Modifier.weight(1f)) { chosen = Filter.Tracks }
                }
            }
            if (items.isEmpty()) {
                item {
                    Text(
                        if (current == Filter.Tracks) "Favorite a track on your phone to see it here."
                        else "Favorite a pack on your phone to see it here.",
                        fontSize = 13.sp,
                        textAlign = TextAlign.Center,
                        color = Color.White.copy(alpha = 0.6f),
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
            } else {
                items(items.size, key = { items[it].rowKey }) { index ->
                    val track = items[index]
                    Button(
                        onClick = { onPlay(track) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.filledTonalButtonColors(),
                        // A pack shows its name; the line below is the session it plays.
                        label = {
                            Text(
                                track.packTitle.ifEmpty { track.title },
                                modifier = Modifier.basicMarquee(iterations = Int.MAX_VALUE),
                                softWrap = false,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        },
                        secondaryLabel = {
                            Text(
                                if (track.packTitle.isEmpty()) "${track.minutes} min"
                                else "${track.title} · ${track.minutes} min",
                                modifier = Modifier.basicMarquee(iterations = Int.MAX_VALUE),
                                softWrap = false,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun FilterChip(title: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier
            .height(32.dp)
            .clip(CircleShape)
            .background(if (selected) Color.White else Color.White.copy(alpha = 0.14f))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            title,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (selected) Color.Black else Color.White,
        )
    }
}
