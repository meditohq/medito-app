@file:UnstableApi

package meditofoundation.medito

import android.content.Intent
import android.util.Log
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

class AudioPlayerService : MediaSessionService(), Player.Listener {

    private lateinit var player: ExoPlayer
    private var mediaSession: MediaSession? = null

    override fun onCreate() {
        super.onCreate()

        player = ExoPlayer.Builder(this)
            .setAudioAttributes(AudioAttributes.DEFAULT, true)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()

        player.addListener(this)

        mediaSession = MediaSession.Builder(this, player).build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        Log.d("AudioPlayerService", "onStartCommand")

        when {
            intent?.getStringExtra(MainActivity.PLAY_URL) != null -> {
                intent.getStringExtra(MainActivity.URL)?.let { url ->
                    playAudio(url)
                    Log.d("AudioPlayerService", "Playing audio from $url")
                }
            }

            intent?.getStringExtra(MainActivity.PAUSE_AUDIO) != null -> {
                pauseAudio()
                Log.d("AudioPlayerService", "Pausing audio")
            }

            else -> {
                Log.d("AudioPlayerService", "Unknown command ${intent?.getStringExtra("command")}")
            }
        }

        return START_NOT_STICKY
    }

    private fun playAudio(url: String) {
        val mediaItem = MediaItem.fromUri(url)
        player.setMediaItem(mediaItem)
        player.prepare()
        player.play()
    }

    private fun pauseAudio() {
        player.pause()
    }

    override fun onDestroy() {
        super.onDestroy()
        player.removeListener(this)
        mediaSession?.run {
            player.release()
            release()
            mediaSession = null
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        val player = mediaSession?.player!!
        if (!player.playWhenReady || player.mediaItemCount == 0) {
            this.player.clearMediaItems()
            this.player.stop()
            stopSelf()
        }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        if (isPlaying) {
            // Player is playing
        } else {
            // Player is paused or stopped
        }
    }

    override fun onse

    override fun onPlaybackStateChanged(playbackState: Int) {
        when (playbackState) {
            Player.STATE_BUFFERING -> {
                // Player is buffering
            }

            Player.STATE_READY -> {
                // Player is ready to play
            }

            Player.STATE_ENDED -> {
                // Player has finished playing
            }

            Player.STATE_IDLE -> {
                // Player is idle
            }
        }
    }
}
