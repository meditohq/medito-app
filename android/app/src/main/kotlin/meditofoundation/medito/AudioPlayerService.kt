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
import android.os.HandlerThread
import androidx.core.app.NotificationCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.util.NotificationUtil
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.MediaStyleNotificationHelper
import io.flutter.embedding.engine.FlutterEngineCache
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.SupervisorJob
import android.media.AudioManager
import android.media.AudioFocusRequest
import android.content.Context

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
    private var hasAudioFocus = false
    
    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.Main + serviceJob)
    private val fadeOutDurationMillis = 10000
    private val handler = Handler(Looper.myLooper() ?: Looper.getMainLooper())
    private val backgroundHandler = Handler(HandlerThread("AudioServiceBackground").apply { start() }.looper)
    private var lastUpdateTime = 0L
    private val UPDATE_INTERVAL = 1000L

    private val positionUpdateRunnable = object : Runnable {
        override fun run() {
            if (!::primaryPlayer.isInitialized) return

            try {
                val runnable = this
                handler.post {
                    try {
                        // Cache player state to minimize main thread work
                        val state = PlaybackState(
                            isPlaying = primaryPlayer.isPlaying,
                            position = primaryPlayer.currentPosition,
                            volume = primaryPlayer.volume.toLong(),
                            speed = Speed(primaryPlayer.playbackParameters.speed.toDouble()),
                            isBuffering = primaryPlayer.playbackState == Player.STATE_BUFFERING,
                            duration = primaryPlayer.duration,
                            isSeeking = primaryPlayer.playbackState == Player.STATE_BUFFERING,
                            isCompleted = primaryPlayer.playbackState == Player.STATE_ENDED,
                            track = primaryPlayer.currentMediaItem?.let { mediaItem ->
                                Track(
                                    id = mediaItem.mediaId,
                                    title = mediaItem.mediaMetadata.title?.toString() ?: "",
                                    description = mediaItem.mediaMetadata.description?.toString() ?: "",
                                    imageUrl = mediaItem.mediaMetadata.artworkUri?.toString() ?: "",
                                    artist = mediaItem.mediaMetadata.artist?.toString() ?: "",
                                )
                            } ?: Track("", "", "", "", "")
                        )

                        // Apply background sound volume on main thread
                        applyBackgroundSoundVolume(state.duration, state.position)

                        // Launch coroutine for state update
                        CoroutineScope(Dispatchers.Main).launch {
                            try {
                                meditoAudioApi?.updatePlaybackState(state) {
                                    if (state.isCompleted && !isCompletionHandled) {
                                        isCompletionHandled = true
                                        handleTrackCompletion(state)
                                    } else if (!isCompletionHandled) {
                                        backgroundHandler.postDelayed(runnable, UPDATE_INTERVAL)
                                    }
                                }
                            } catch (e: Exception) {
                                e.printStackTrace()
                                if (!isCompletionHandled) {
                                    backgroundHandler.postDelayed(runnable, UPDATE_INTERVAL)
                                }
                            }
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                        if (!isCompletionHandled) {
                            backgroundHandler.postDelayed(runnable, UPDATE_INTERVAL)
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
                if (!isCompletionHandled) {
                    backgroundHandler.postDelayed(this, UPDATE_INTERVAL)
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
                meditoAudioApi?.let { api ->
                    api.handleCompletedTrack(completionData) { result ->
                        if (result.isSuccess) {
                            SharedPreferencesManager.clearCompletionData(this@AudioPlayerService)
                        }
                        finishPlayback()
                    }
                } ?: finishPlayback()
            }
        }

        private fun finishPlayback() {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }

        private fun applyBackgroundSoundVolume(trackDuration: Long, currentPosition: Long) {
            try {
                if (trackDuration != C.TIME_UNSET && 
                    trackDuration - currentPosition <= fadeOutDurationMillis && 
                    trackDuration > fadeOutDurationMillis) {
                    val volumeFraction =
                        (trackDuration - currentPosition).toFloat() / fadeOutDurationMillis
                    backgroundMusicPlayer.volume =
                        backgroundMusicVolume * volumeFraction
                } else {
                    backgroundMusicPlayer.volume = backgroundMusicVolume
                }
            } catch (e: Exception) {
                e.printStackTrace()
                // Default to the set volume if there's an error
                backgroundMusicPlayer.volume = backgroundMusicVolume
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        
        val audioAttributes = AudioAttributes.Builder()
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
            .setUsage(C.USAGE_MEDIA)
            .build()

        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                DefaultLoadControl.DEFAULT_MIN_BUFFER_MS,
                DefaultLoadControl.DEFAULT_MAX_BUFFER_MS,
                DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_MS,
                DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS
            )
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()

        primaryPlayer = ExoPlayer.Builder(this)
            .setAudioAttributes(audioAttributes, true)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .setLoadControl(loadControl)
            .build().apply {
                addListener(object : Player.Listener {
                    override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                        if (playWhenReady) {
                            requestAudioFocus()
                        } else {
                            abandonAudioFocus()
                        }
                    }
                })
            }

        backgroundMusicPlayer = ExoPlayer.Builder(this)
            .setAudioAttributes(audioAttributes, true)
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_LOCAL)
            .setLoadControl(loadControl)
            .build()

        primaryPlayer.addListener(this)

        primaryMediaSession = MediaSession.Builder(this, primaryPlayer)
            .setCallback(this)
            .setId("MeditoAudioSession_${System.currentTimeMillis()}")
            .build()
    }

    override fun onDestroy() {
        abandonAudioFocus()
        serviceJob.cancel()
        handler.post {
            backgroundHandler.removeCallbacks(positionUpdateRunnable)
            primaryPlayer.stop()
            backgroundMusicPlayer.stop()
            primaryPlayer.release()
            backgroundMusicPlayer.release()
            primaryPlayer.removeListener(this)
            backgroundMusicPlayer.removeListener(this)
            primaryMediaSession?.run {
                player.release()
                release()
                primaryMediaSession = null
            }
        }
        super.onDestroy()
    }

    override fun onPlayerStateChanged(playWhenReady: Boolean, playbackState: Int) {
        super.onPlayerStateChanged(playWhenReady, playbackState)
        
        if (playWhenReady && playbackState == Player.STATE_READY) {
            backgroundMusicPlayer.play()
            isCompletionHandled = false
            
            // Ensure updates are running
            backgroundHandler.removeCallbacks(positionUpdateRunnable)
            backgroundHandler.post(positionUpdateRunnable)
        } else if (!playWhenReady) {
            backgroundMusicPlayer.pause()
        }

        // Update notification to reflect current state
        updateNotification()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Only stop service if not playing
        if (!primaryPlayer.isPlaying) {
            serviceScope.launch {
                backgroundHandler.removeCallbacks(positionUpdateRunnable)
                clearNotification()
                primaryPlayer.stop()
                backgroundMusicPlayer.stop()
                primaryPlayer.clearMediaItems()
                backgroundMusicPlayer.clearMediaItems()
                stopSelf()
            }
        }
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

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Create and show notification immediately
        val initialNotification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Medito")
            .setContentText("Preparing media playback...")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setSilent(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
            
        startForeground(NOTIFICATION_ID, initialNotification)
        
        // Check for required permissions
        if (!hasRequiredPermissions()) {
            stopSelf()
            return START_NOT_STICKY
        }
        
        super.onStartCommand(intent, flags, startId)
        
        // Move initialization off main thread
        CoroutineScope(Dispatchers.Default).launch {
            FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID)?.let { engine ->
                withContext(Dispatchers.Main) {
                    MeditoAudioServiceApi.setUp(engine.dartExecutor.binaryMessenger, this@AudioPlayerService)
                    meditoAudioApi = MeditoAudioServiceCallbackApi(engine.dartExecutor.binaryMessenger)
                }
            }

            // Start position updates
            withContext(Dispatchers.Main) {
                backgroundHandler.removeCallbacks(positionUpdateRunnable)
                backgroundHandler.post(positionUpdateRunnable)
            }
        }

        return START_STICKY
    }

    private fun hasRequiredPermissions(): Boolean {
        // Add any media playback related permission checks here
        // For example, checking audio focus permissions if needed
        return true
    }

    override fun playAudio(audioData: AudioData): Boolean {
        if (!::primaryPlayer.isInitialized || !::backgroundMusicPlayer.isInitialized) {
            return false
        }
        
        isCompletionHandled = false
        
        handler.post {
            // Stop any existing playback
            primaryPlayer.stop()
            primaryPlayer.clearMediaItems()

            val primaryMediaItem = MediaItem.Builder()
                .setUri(audioData.url)
                .setMediaId(audioData.track.id)
                .setMediaMetadata(
                    MediaMetadata.Builder()
                        .setTitle(audioData.track.title)
                        .setArtist(audioData.track.artist)
                        .setDescription(audioData.track.description)
                        .setArtworkUri(audioData.track.imageUrl?.let { Uri.parse(it) })
                        .build()
                )
                .build()

            primaryPlayer.setMediaItem(primaryMediaItem)
            primaryPlayer.prepare()
            primaryPlayer.play()

            // Update to media notification
            updateNotification()

            // Ensure position updates are running
            backgroundHandler.removeCallbacks(positionUpdateRunnable)
            backgroundHandler.post(positionUpdateRunnable)

            playBackgroundSound()
        }

        return true
    }

    private fun updateNotification() {
        if (!::primaryPlayer.isInitialized) return
        
        val mediaItem = primaryPlayer.currentMediaItem ?: return
        val title = mediaItem.mediaMetadata?.title?.toString() ?: "Medito"
        val artist = mediaItem.mediaMetadata?.artist?.toString() ?: "Medito"
        
        serviceScope.launch {
            try {
                val artworkBitmap = mediaItem.mediaMetadata?.artworkUri?.let { uri ->
                    try {
                        withContext(Dispatchers.IO) {
                            val inputStream = java.net.URL(uri.toString()).openStream()
                            BitmapFactory.decodeStream(inputStream)
                        }
                    } catch (e: Exception) {
                        null
                    }
                }
                
                withContext(Dispatchers.Main) {
                    val newNotification = createNotificationBuilder(title, artist, artworkBitmap)
                        .build()
                    
                    notification = newNotification
                    NotificationUtil.setNotification(
                        this@AudioPlayerService,
                        NOTIFICATION_ID,
                        notification
                    )
                }
            } catch (e: Exception) {
                e.printStackTrace()
                withContext(Dispatchers.Main) {
                    val fallbackNotification = createNotificationBuilder(title, artist, null)
                        .build()
                    
                    notification = fallbackNotification
                    NotificationUtil.setNotification(
                        this@AudioPlayerService,
                        NOTIFICATION_ID,
                        notification
                    )
                }
            }
        }
    }

    private fun createNotificationBuilder(
        title: String,
        artist: String,
        artworkBitmap: Bitmap?
    ): NotificationCompat.Builder {
        return NotificationCompat.Builder(this@AudioPlayerService, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(artist)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setLargeIcon(artworkBitmap)
            .setSilent(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setOngoing(true)
            .apply {
                primaryMediaSession?.let {
                    setStyle(MediaStyleNotificationHelper.MediaStyle(it))
                }
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
        val duration = primaryPlayer.duration
        val currentPosition = primaryPlayer.currentPosition
        
        if (duration == C.TIME_UNSET) {
            return
        }
        
        if (currentPosition + 10000 > duration) {
            primaryPlayer.seekTo(duration)
            return
        }
        primaryPlayer.seekTo(currentPosition + 10000)
    }

    override fun skip10SecondsBackward() {
        val currentPosition = primaryPlayer.currentPosition
        
        if (currentPosition < 10000) {
            primaryPlayer.seekTo(0)
            return
        }
        primaryPlayer.seekTo(currentPosition - 10000)
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

    private fun requestAudioFocus() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val result = audioManager.requestAudioFocus(
            AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setWillPauseWhenDucked(true)
                .setOnAudioFocusChangeListener { focusChange ->
                    when (focusChange) {
                        AudioManager.AUDIOFOCUS_GAIN -> {
                            hasAudioFocus = true
                            primaryPlayer.volume = 1f
                            if (!primaryPlayer.isPlaying) {
                                primaryPlayer.play()
                            }
                        }
                        AudioManager.AUDIOFOCUS_LOSS -> {
                            hasAudioFocus = false
                            primaryPlayer.pause()
                        }
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                            hasAudioFocus = false
                            primaryPlayer.pause()
                        }
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                            primaryPlayer.volume = 0.3f
                        }
                    }
                }
                .build()
        )
        hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonAudioFocus() {
        if (hasAudioFocus) {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.abandonAudioFocusRequest(
                AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(
                        android.media.AudioAttributes.Builder()
                            .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                            .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                    .build()
            )
            hasAudioFocus = false
        }
    }

    companion object {
        const val CHANNEL_ID = "medito_media_channel"
        const val NOTIFICATION_ID = 101011
    }
}
