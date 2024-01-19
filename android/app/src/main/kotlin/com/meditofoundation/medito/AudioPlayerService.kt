package meditofoundation.medito

import AudioData
import MeditoAudioServiceApi
import MeditoAudioServiceCallbackApi
import PlaybackState
import Speed
import Track
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.embedding.engine.FlutterEngineCache

class AudioPlayerService : MediaSessionService(), Player.Listener, MeditoAudioServiceApi,
    MediaSession.Callback {

    private var backgroundMusicVolume: Float = 0.0F
    private var backgroundSoundUri: String? = null
    private lateinit var primaryPlayer: ExoPlayer
    private lateinit var backgroundMusicPlayer: ExoPlayer
    private var primaryMediaSession: MediaSession? = null
    private var meditoAudioApi: MeditoAudioServiceCallbackApi? = null

    override fun onCreate() {
        super.onCreate()

        primaryPlayer = ExoPlayer.Builder(this)
            .setAudioAttributes(AudioAttributes.DEFAULT, false)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()

        backgroundMusicPlayer = ExoPlayer.Builder(this)
            .setAudioAttributes(AudioAttributes.DEFAULT, false)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()

        primaryPlayer.addListener(this)

        primaryMediaSession = MediaSession.Builder(this, primaryPlayer)
            .setCallback(this)
            .build()

        FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID)?.let { engine ->
            MeditoAudioServiceApi.setUp(engine.dartExecutor.binaryMessenger, this)
            meditoAudioApi = MeditoAudioServiceCallbackApi(engine.dartExecutor.binaryMessenger)
        }

    }

    override fun onDestroy() {
        super.onDestroy()

        handler.removeCallbacks(positionUpdateRunnable)

        primaryPlayer.removeListener(this)
        backgroundMusicPlayer.removeListener(this)

        handler.removeCallbacks(positionUpdateRunnable)

        primaryMediaSession?.run {
            player.release()
            release()
            primaryMediaSession = null
        }

    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        handler.removeCallbacks(positionUpdateRunnable)

        val player = primaryMediaSession?.player!!
        if (!player.playWhenReady || player.mediaItemCount == 0) {
            this.primaryPlayer.clearMediaItems()
            this.backgroundMusicPlayer.clearMediaItems()
            this.primaryPlayer.stop()
            this.backgroundMusicPlayer.stop()
            stopSelf()
        }
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return primaryMediaSession
    }

    override fun playAudio(audioData: AudioData): Boolean {

        val primaryMediaItem = MediaItem.Builder()
            .setUri(audioData.url)
            .setMediaId(audioData.url)
            .setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle(audioData.track.title)
                    .setArtist(audioData.track.artist)
                    .setDescription(audioData.track.description)
                    .setArtworkUri(Uri.parse(audioData.track.imageUrl))
                    .build()
            )
            .build()


        primaryPlayer.setMediaItem(primaryMediaItem)
        primaryPlayer.prepare()
        primaryPlayer.play()

        handler.post(positionUpdateRunnable)

        playBackgroundSound()
        return true
    }

    override fun playBackgroundSound() {
        if (backgroundSoundUri == null) {
            return
        }

        val backgroundMediaItem = MediaItem.Builder()
            .setUri(backgroundSoundUri)
            .build()

        backgroundMusicPlayer.repeatMode = Player.REPEAT_MODE_ONE
        backgroundMusicPlayer.setMediaItem(backgroundMediaItem)
        backgroundMusicPlayer.prepare()
        backgroundMusicPlayer.play()
    }

    override fun setBackgroundSound(uri: String?) {
        this.backgroundSoundUri = uri
    }

    override fun stopBackgroundSound() {
        backgroundMusicPlayer.stop()
    }

    override fun setBackgroundSoundVolume(volume: Double) {
        this.backgroundMusicVolume = volume.toFloat() / 100
        backgroundMusicPlayer.volume = this.backgroundMusicVolume
    }

    override fun seekToPosition(position: Long) {
        primaryPlayer.seekTo(position)
    }

    override fun setSpeed(speed: Double) {
        primaryPlayer.setPlaybackSpeed(speed.toFloat())
    }

    override fun skip10SecondsForward() {
        if (primaryPlayer.currentPosition + 10000 > primaryPlayer.duration) {
            primaryPlayer.seekTo(primaryPlayer.duration)
            return
        }
        primaryPlayer.seekTo(primaryPlayer.currentPosition + 10000)
    }

    override fun skip10SecondsBackward() {
        if (primaryPlayer.duration - primaryPlayer.currentPosition < 10000) {
            primaryPlayer.seekTo(0)
            return
        }
        primaryPlayer.seekTo(primaryPlayer.currentPosition - 10000)
    }

    override fun stopAudio() {
        primaryPlayer.stop()
        backgroundMusicPlayer.stop()
        handler.removeCallbacks(positionUpdateRunnable)

    }

    override fun playPauseAudio() {
        if (primaryPlayer.isPlaying) {
            primaryPlayer.pause()
            backgroundMusicPlayer.pause()
        } else {
            primaryPlayer.play()
            backgroundMusicPlayer.play()
        }
    }

    private val fadeOutDurationMillis = 10000
    private val handler = Handler(Looper.getMainLooper())
    private val positionUpdateRunnable = object : Runnable {
        override fun run() {

            val currentPosition = primaryPlayer.currentPosition
            val trackDuration = primaryPlayer.duration

            applyBackgroundSoundVolume(trackDuration, currentPosition)

            val state = PlaybackState(
                isPlaying = primaryPlayer.isPlaying,
                position = primaryPlayer.currentPosition,
                volume = (primaryPlayer.volume * 100).toLong(),
                speed = Speed(primaryPlayer.playbackParameters.speed.toDouble()),
                isBuffering = primaryPlayer.playbackState == Player.STATE_BUFFERING,
                duration = primaryPlayer.duration,
                isSeeking = primaryPlayer.playbackState == Player.STATE_BUFFERING,
                isCompleted = primaryPlayer.playbackState == Player.STATE_ENDED,
                track = Track(
                    title = primaryPlayer.currentMediaItem?.mediaMetadata?.title.toString(),
                    description = primaryPlayer.currentMediaItem?.mediaMetadata?.description.toString(),
                    imageUrl = primaryPlayer.currentMediaItem?.mediaMetadata?.artworkUri.toString(),
                    artist = primaryPlayer.currentMediaItem?.mediaMetadata?.artist.toString(),
                ),
            )

            meditoAudioApi?.updatePlaybackState(state) {}

            handler.postDelayed(this, 250)
        }

        private fun applyBackgroundSoundVolume(trackDuration: Long, currentPosition: Long) {
            if (trackDuration - currentPosition <= fadeOutDurationMillis && trackDuration > fadeOutDurationMillis) {
                val volumeFraction =
                    (trackDuration - currentPosition).toFloat() / fadeOutDurationMillis
                backgroundMusicPlayer.volume =
                    backgroundMusicVolume * volumeFraction
            } else {
                backgroundMusicPlayer.volume = backgroundMusicVolume
            }
        }
    }
    
}
