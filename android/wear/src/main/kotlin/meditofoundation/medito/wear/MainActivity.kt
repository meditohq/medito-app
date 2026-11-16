package meditofoundation.medito.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.material3.ColorScheme
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MeditoWatchApp() }
    }

    override fun onResume() {
        super.onResume()
        WatchRepository.refresh()
    }
}

/** Monochrome, like the phone app (no brand purple). */
private val MeditoColors = ColorScheme(
    primary = Color.White,
    onPrimary = Color.Black,
    primaryContainer = Color(0xFF2A2A2A),
    onPrimaryContainer = Color.White,
    secondary = Color.White,
    onSecondary = Color.Black,
    surfaceContainerLow = Color(0xFF1A1A1A),
    surfaceContainer = Color(0xFF242424),
    surfaceContainerHigh = Color(0xFF2E2E2E),
    onSurface = Color.White,
    onSurfaceVariant = Color(0xFFB3B3B3),
    background = Color.Black,
    onBackground = Color.White,
)

private object Routes {
    const val HOME = "home"
    const val DOWNLOADS = "downloads"
    const val FAVORITES = "favorites"
    const val PLAYER = "player"
}

@Composable
fun MeditoWatchApp() {
    val state by WatchRepository.state.collectAsState()
    val navController = rememberSwipeDismissableNavController()
    // The session the player route plays.
    var playing by remember { mutableStateOf<WatchTrack?>(null) }

    val play: (WatchTrack) -> Unit = {
        playing = it
        navController.navigate(Routes.PLAYER)
    }

    // Signed out on the phone: leave whatever that account had open.
    LaunchedEffect(state.synced) {
        if (!state.synced) navController.popBackStack(Routes.HOME, inclusive = false)
    }

    MaterialTheme(colorScheme = MeditoColors) {
        AppScaffold {
            SwipeDismissableNavHost(navController = navController, startDestination = Routes.HOME) {
                composable(Routes.HOME) {
                    HomeScreen(
                        state = state,
                        onPlay = play,
                        onDownloads = { navController.navigate(Routes.DOWNLOADS) },
                        onFavorites = { navController.navigate(Routes.FAVORITES) },
                    )
                }
                composable(Routes.DOWNLOADS) { DownloadsScreen(onPlay = play) }
                composable(Routes.FAVORITES) {
                    FavoritesScreen(favorites = state.favorites, onPlay = play)
                }
                composable(Routes.PLAYER) {
                    playing?.let { PlayerScreen(track = it, onDone = { navController.popBackStack() }) }
                }
            }
        }
    }
}
