package meditofoundation.medito

import android.content.Intent
import android.util.Log
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

class AudioPlayerService : MediaSessionService() {

    private lateinit var player: ExoPlayer
    private lateinit var mediaSession: MediaSession

    override fun onCreate() {
        super.onCreate()
        player = ExoPlayer.Builder(this)
            .setAudioAttributes(AudioAttributes.DEFAULT, true)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()
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
        player.release()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession {
        return mediaSession
    }
}
