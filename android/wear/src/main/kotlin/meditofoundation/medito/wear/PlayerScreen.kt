package meditofoundation.medito.wear

import android.content.ComponentName
import android.content.Context
import android.media.AudioManager
import android.view.HapticFeedbackConstants
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import androidx.wear.compose.material3.CircularProgressIndicator
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.Text
import kotlinx.coroutines.delay

private enum class Phase { Connecting, Playing, Paused, Finished, NeedsHeadphones, Failed }

/**
 * A progress ring round the edge of the screen, play/pause in the middle, time
 * left below — like the Apple Watch player. The crown sets the volume.
 * Leaving the screen stops the session, as on the phone.
 */
@Composable
fun PlayerScreen(track: WatchTrack, onDone: () -> Unit) {
    val context = LocalContext.current
    val view = LocalView.current
    var controller by remember { mutableStateOf<MediaController?>(null) }
    var phase by remember { mutableStateOf(Phase.Connecting) }
    var positionMs by remember { mutableFloatStateOf(0f) }
    var durationMs by remember { mutableFloatStateOf(track.durationMs.toFloat()) }

    DisposableEffect(track.rowKey) {
        val token = SessionToken(context, ComponentName(context, PlaybackService::class.java))
        val future = MediaController.Builder(context, token).buildAsync()
        future.addListener({
            val c = runCatching { future.get() }.getOrNull() ?: return@addListener
            controller = c
            c.addListener(object : Player.Listener {
                override fun onEvents(player: Player, events: Player.Events) {
                    phase = when {
                        player.playerError != null -> Phase.Failed
                        player.playbackState == Player.STATE_ENDED -> Phase.Finished
                        player.playbackSuppressionReason ==
                            Player.PLAYBACK_SUPPRESSION_REASON_UNSUITABLE_AUDIO_OUTPUT -> Phase.NeedsHeadphones
                        player.isPlaying -> Phase.Playing
                        player.playbackState == Player.STATE_BUFFERING ||
                            player.playbackState == Player.STATE_IDLE -> Phase.Connecting
                        else -> Phase.Paused
                    }
                    if (events.contains(Player.EVENT_PLAYBACK_STATE_CHANGED) &&
                        player.playbackState == Player.STATE_ENDED
                    ) {
                        view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                    }
                }

                override fun onPlayerError(error: PlaybackException) {
                    phase = Phase.Failed
                }
            })
            c.setMediaItem(PlaybackService.mediaItem(track))
            c.prepare()
            c.play()
        }, ContextCompat.getMainExecutor(context))

        onDispose {
            controller?.run {
                stop()
                clearMediaItems()
            }
            MediaController.releaseFuture(future)
            controller = null
        }
    }

    LaunchedEffect(controller) {
        while (true) {
            controller?.let {
                positionMs = it.currentPosition.toFloat()
                if (it.duration > 0) durationMs = it.duration.toFloat()
            }
            delay(500)
        }
    }

    val progress = when (phase) {
        Phase.Finished -> 1f
        else -> if (durationMs > 0) (positionMs / durationMs).coerceIn(0f, 1f) else 0f
    }
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .onRotaryScrollEvent {
                adjustVolume(context, it.verticalScrollPixels)
                true
            }
            .focusRequester(focusRequester)
            .focusable(),
        contentAlignment = Alignment.Center,
    ) {
        // Drawn by hand (like the Apple Watch ring): Wear M3's indicator
        // didn't render the filled arc in this colour scheme.
        Canvas(Modifier.fillMaxSize().padding(7.dp)) {
            val stroke = Stroke(width = 6.dp.toPx(), cap = StrokeCap.Round)
            drawArc(Color.White.copy(alpha = 0.2f), 0f, 360f, useCenter = false, style = stroke)
            if (progress > 0f) {
                drawArc(Color.White, -90f, 360f * progress, useCenter = false, style = stroke)
            }
        }

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(horizontal = 28.dp),
        ) {
            Text(
                track.title,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
            )

            val centre = Modifier.size(56.dp).clip(CircleShape)
            when (phase) {
                Phase.Playing, Phase.Paused -> Box(
                    centre.background(Color.White).clickable {
                        controller?.let { if (it.isPlaying) it.pause() else it.play() }
                    },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        painterResource(if (phase == Phase.Playing) R.drawable.ic_pause else R.drawable.ic_play),
                        contentDescription = if (phase == Phase.Playing) "Pause" else "Play",
                        tint = Color.Black,
                        modifier = Modifier.size(26.dp),
                    )
                }
                Phase.Finished -> Box(centre.clickable(onClick = onDone), contentAlignment = Alignment.Center) {
                    Icon(painterResource(R.drawable.ic_check), contentDescription = "Done", modifier = Modifier.size(34.dp))
                }
                else -> Box(centre, contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(modifier = Modifier.size(28.dp))
                }
            }

            Text(
                when (phase) {
                    Phase.Finished -> "Well done"
                    Phase.NeedsHeadphones -> "Connect headphones to listen"
                    Phase.Failed -> "Couldn't play this session"
                    Phase.Connecting -> "${track.minutes} min"
                    else -> "-" + format(durationMs - positionMs)
                },
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.7f),
                textAlign = TextAlign.Center,
            )
        }
    }
}

private fun adjustVolume(context: Context, delta: Float) {
    if (delta == 0f) return
    val audio = context.getSystemService(AudioManager::class.java) ?: return
    audio.adjustStreamVolume(
        AudioManager.STREAM_MUSIC,
        if (delta > 0) AudioManager.ADJUST_RAISE else AudioManager.ADJUST_LOWER,
        AudioManager.FLAG_SHOW_UI,
    )
}

private fun format(ms: Float): String {
    val s = (maxOf(ms, 0f) / 1000).toInt()
    return "%d:%02d".format(s / 60, s % 60)
}
