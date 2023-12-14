package meditofoundation.medito

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer

class AudioPlayerService : Service() {
    private lateinit var player: ExoPlayer

    override fun onCreate() {
        super.onCreate()
        player = ExoPlayer.Builder(this).build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AudioPlayerService", "onStartCommand")
        when (intent?.getStringExtra("command")) {
            MainActivity.PLAY_URL -> {
                intent.getStringExtra("url")?.let { url ->
                    playAudio(url)
                    Log.d("AudioPlayerService", "Playing audio from $url")
                }
            }
            MainActivity.PAUSE_AUDIO -> {
                pauseAudio()
                Log.d("AudioPlayerService", "Pausing audio")
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

    override fun onBind(intent: Intent?): IBinder? {
        return null // We are not using a bound service
    }
}
