package meditofoundation.medito.wear

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.*

@Composable
fun DownloadsScreen(onPlay: (WatchTrack) -> Unit) {
    val tracks by WatchDownloads.tracks.collectAsState()
    val listState = rememberScalingLazyListState()
    ScreenScaffold(scrollState = listState) {
        ScalingLazyColumn(state = listState, modifier = Modifier.fillMaxSize()) {
            item { ListHeader { Text("Downloads") } }
            if (tracks.isEmpty()) item { Text("Send sessions from Downloads in Medito on your phone to listen offline.") }
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
