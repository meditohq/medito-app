@file:UnstableApi

package meditofoundation.medito

import AudioData
import CompletionData
import MeditoAudioServiceApi
import MeditoAudioServiceCallbackApi
import PlaybackState
import Speed
import Track
import android.app.Notification
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.util.NotificationUtil
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.MediaStyleNotificationHelper
import io.flutter.embedding.engine.FlutterEngineCache
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class AudioPlayerService : MediaSessionService(), Player.Listener, MeditoAudioServiceApi,
    MediaSession.Callback {

    private lateinit var notification: Notification
    private var backgroundMusicVolume: Float = 0.0F
    private var backgroundSoundUri: String? = null
    private lateinit var primaryPlayer: ExoPlayer
    private lateinit var backgroundMusicPlayer: ExoPlayer
    private var primaryMediaSession: MediaSession? = null
    private var meditoAudioApi: MeditoAudioServiceCallbackApi? = null
    private var isCompletionHandled = false

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
            .setWakeMode(C.WAKE_MODE_LOCAL)
            .build()

        primaryPlayer.addListener(this)

        primaryMediaSession = MediaSession.Builder(this, primaryPlayer)
            .setCallback(this)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()

        primaryPlayer.release()
        backgroundMusicPlayer.release()

        handler.removeCallbacks(positionUpdateRunnable)

        primaryPlayer.removeListener(this)
        backgroundMusicPlayer.removeListener(this)

        primaryMediaSession?.run {
            player.release()
            release()
            primaryMediaSession = null
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onPlayerStateChanged(playWhenReady: Boolean, playbackState: Int) {
        if (playWhenReady && playbackState == Player.STATE_READY) {
            backgroundMusicPlayer.play()
            isCompletionHandled = false
        } else if (!playWhenReady) {
            backgroundMusicPlayer.pause()
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        handler.removeCallbacks(positionUpdateRunnable)
        clearNotification()
        this.primaryPlayer.stop()
        this.backgroundMusicPlayer.stop()
        this.primaryPlayer.clearMediaItems()
        this.backgroundMusicPlayer.clearMediaItems()
        stopSelf()
    }

    override fun stopService(name: Intent?): Boolean {
        return super.stopService(name)
    }

    private fun clearNotification() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        NotificationUtil.setNotification(
            this@AudioPlayerService,
            NOTIFICATION_ID,
            null
        )
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return primaryMediaSession
    }

    override fun playAudio(audioData: AudioData): Boolean {
        isCompletionHandled = false

        val primaryMediaItem = MediaItem.Builder()
            .setUri(audioData.url)
            .setMediaId(audioData.track.id)
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

        handler.postDelayed(positionUpdateRunnable, 500)

        playBackgroundSound()
        updateNotification()

        return true
    }

    private fun createMediaNotification(artworkBitmap: Bitmap?): Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(primaryPlayer.currentMediaItem?.mediaMetadata?.title ?: "Medito")
            .setContentText(primaryPlayer.currentMediaItem?.mediaMetadata?.artist ?: "Medito")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setLargeIcon(artworkBitmap)
            .setSilent(true)
            .setStyle(primaryMediaSession?.let { MediaStyleNotificationHelper.MediaStyle(it) })

        return builder.build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID)?.let { engine ->
            MeditoAudioServiceApi.setUp(engine.dartExecutor.binaryMessenger, this)
            meditoAudioApi = MeditoAudioServiceCallbackApi(engine.dartExecutor.binaryMessenger)
        }

        notification = createPlaceholderNotification()
        startForeground(NOTIFICATION_ID, notification)
        return START_STICKY
    }

    private fun createPlaceholderNotification(): Notification {
        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Medito audio starting")
            .setContentText("Preparing...")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setSilent(true)
            .setStyle(primaryMediaSession?.let { MediaStyleNotificationHelper.MediaStyle(it) })
        return notificationBuilder.build()
    }

    private fun updateNotification() {
        CoroutineScope(Dispatchers.Main).launch {
            val artworkUri = primaryPlayer.currentMediaItem?.mediaMetadata?.artworkUri
            val artworkBitmap = withContext(Dispatchers.IO) {
                artworkUri?.let { downloadBitmap(it) }
            }
            notification = createMediaNotification(artworkBitmap)
            try {
                NotificationUtil.setNotification(
                    this@AudioPlayerService,
                    NOTIFICATION_ID,
                    notification
                )
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private suspend fun downloadBitmap(uri: Uri): Bitmap? = withContext(Dispatchers.IO) {
        try {
            val inputStream = java.net.URL(uri.toString()).openStream()
            BitmapFactory.decodeStream(inputStream)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
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

    override fun pauseBackgroundSound() {
        backgroundMusicPlayer.pause()
    }

    override fun setBackgroundSound(uri: String?) {
        this.backgroundSoundUri = uri
    }

    override fun stopBackgroundSound() {
        backgroundMusicPlayer.stop()
    }

    override fun setBackgroundSoundVolume(volume: Double) {
        this.backgroundMusicVolume = volume.toFloat()
        backgroundMusicPlayer.volume = this.backgroundMusicVolume
    }

    override fun seekToPosition(position: Long) {
        isCompletionHandled = false
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
        isCompletionHandled = false
        primaryPlayer.stop()
        backgroundMusicPlayer.stop()
        clearNotification()
    }

    override fun playPauseAudio() {
        isCompletionHandled = false
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
                volume = (primaryPlayer.volume).toLong(),
                speed = Speed(primaryPlayer.playbackParameters.speed.toDouble()),
                isBuffering = primaryPlayer.playbackState == Player.STATE_BUFFERING,
                duration = primaryPlayer.duration,
                isSeeking = primaryPlayer.playbackState == Player.STATE_BUFFERING,
                isCompleted = primaryPlayer.playbackState == Player.STATE_ENDED,
                track = Track(
                    id = primaryPlayer.currentMediaItem?.mediaId.toString(),
                    title = primaryPlayer.currentMediaItem?.mediaMetadata?.title.toString(),
                    description = primaryPlayer.currentMediaItem?.mediaMetadata?.description.toString(),
                    imageUrl = primaryPlayer.currentMediaItem?.mediaMetadata?.artworkUri.toString(),
                    artist = primaryPlayer.currentMediaItem?.mediaMetadata?.artist.toString(),
                ),
            )

            meditoAudioApi?.updatePlaybackState(state) {
                if (primaryPlayer.playbackState == Player.STATE_ENDED && !isCompletionHandled) {
                    isCompletionHandled = true
                    handleTrackCompletion(state)
                } else if (primaryPlayer.playbackState != Player.STATE_ENDED) {
                    handler.postDelayed(this, 250)
                }
            }
        }

        private fun handleTrackCompletion(state: PlaybackState) {
            val completionData = createCompletionData(state)
            saveAndSendCompletionData(completionData)
        }

        private fun createCompletionData(state: PlaybackState): CompletionData {
            return CompletionData(
                trackId = state.track.id,
                duration = state.duration,
                fileId = state.track.title,
                guideId = state.track.artist,
                timestamp = System.currentTimeMillis()
            )
        }

        private fun saveAndSendCompletionData(completionData: CompletionData) {
            SharedPreferencesManager.saveCompletionData(this@AudioPlayerService, completionData)

            CoroutineScope(Dispatchers.Main).launch {
                // Attempt to send data
                meditoAudioApi?.handleCompletedTrack(completionData) { result ->
                    if (result.isSuccess) {
                        SharedPreferencesManager.clearCompletionData(this@AudioPlayerService)
                    }

                    finishPlayback()
                }
            }
        }

        private fun finishPlayback() {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
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

    companion object {
        const val CHANNEL_ID = "medito_media_channel"
        const val NOTIFICATION_ID = 101011
    }
}
