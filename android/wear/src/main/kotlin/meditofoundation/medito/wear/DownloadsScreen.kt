package meditofoundation.medito.wear

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.*

@Composable
fun DownloadsScreen(onPlay: (WatchTrack) -> Unit) {
    val tracks by WatchDownloads.tracks.collectAsState()
    val incoming by WatchDownloads.incoming.collectAsState()
    val arriving = incoming.filter { pending -> tracks.none { it.fileId == pending.fileId } }
    val listState = rememberScalingLazyListState()
    ScreenScaffold(scrollState = listState) {
        ScalingLazyColumn(state = listState, modifier = Modifier.fillMaxSize()) {
            item { ListHeader { Text("Downloads") } }
            items(arriving.size, key = { "incoming-" + arriving[it].fileId }) { index ->
                val track = arriving[index]
                Button(onClick = {}, enabled = false, modifier = Modifier.fillMaxWidth(),
                    label = { Text(track.title) }, secondaryLabel = { Text("Downloading from phone…") })
            }
            if (tracks.isEmpty() && arriving.isEmpty()) item {
                Text(
                    "Send sessions from Downloads in Medito on your phone. They appear here once they've copied over, which can take a minute or two.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 8.dp),
                )
            }
            items(tracks.size, key = { tracks[it].fileId }) { index ->
                val track = tracks[index]
                androidx.compose.foundation.layout.Column {
                    Button(onClick = { onPlay(track) }, modifier = Modifier.fillMaxWidth(),
                        label = { Text(track.title) }, secondaryLabel = { Text("${track.guide} · ${track.minutes} min · Offline") })
                    TextButton(onClick = { WatchDownloads.remove(track) }, modifier = Modifier.fillMaxWidth()) { Text("Remove from watch") }
                }
            }
        }
    }
}
