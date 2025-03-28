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
import android.util.Log
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
import android.os.Binder

@UnstableApi
class AudioPlayerService : MediaSessionService(), Player.Listener, MeditoAudioServiceApi {

    // Inner class that allows binding to this service
    inner class LocalBinder : Binder() {
        val service: AudioPlayerService
            get() = this@AudioPlayerService
    }
    
    private val binder = LocalBinder()
    private lateinit var notification: Notification
    private var backgroundMusicVolume: Float = 0.0F
    private var backgroundSoundUri: String? = null
    private lateinit var primaryPlayer: ExoPlayer
    private lateinit var backgroundMusicPlayer: ExoPlayer
    private var primaryMediaSession: MediaSession? = null
    private var meditoAudioApi: MeditoAudioServiceCallbackApi? = null
    private var isCompletionHandled = false
    private var hasAudioFocus = false
    private var isServiceFullyInitialized = false
    
    // Result callback when service is ready
    private var readinessCallback: ((Boolean) -> Unit)? = null

    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.Main + serviceJob)
    private val fadeOutDurationMillis = 10000
    private val handler = Handler(Looper.myLooper() ?: Looper.getMainLooper())
    private val backgroundHandler =
        Handler(HandlerThread("AudioServiceBackground").apply { start() }.looper)
    private val updateIntervalMs = 1000L

    private val positionUpdateRunnable = object : Runnable {
        override fun run() {
            if (!::primaryPlayer.isInitialized) {
                Log.e(TAG, "❌ Position update runnable: primaryPlayer not initialized")
                return
            }

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
                                    description = mediaItem.mediaMetadata.description?.toString()
                                        ?: "",
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
                                Log.d(
                                    TAG,
                                    "🔊 Updating playback state: isPlaying=${state.isPlaying}, position=${state.position}ms, playbackState=${primaryPlayer.playbackState}"
                                )
                                meditoAudioApi?.updatePlaybackState(state) {
                                    if (state.isCompleted && !isCompletionHandled) {
                                        isCompletionHandled = true
                                        handleTrackCompletion(state)
                                    } else if (!isCompletionHandled) {
                                        backgroundHandler.postDelayed(runnable, updateIntervalMs)
                                    }
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "❌ Error updating playback state: ${e.message}")
                                e.printStackTrace()
                                if (!isCompletionHandled) {
                                    backgroundHandler.postDelayed(runnable, updateIntervalMs)
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error in position update runnable: ${e.message}")
                        e.printStackTrace()
                        if (!isCompletionHandled) {
                            backgroundHandler.postDelayed(runnable, updateIntervalMs)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Exception in position update outer block: ${e.message}")
                e.printStackTrace()
                if (!isCompletionHandled) {
                    backgroundHandler.postDelayed(this, updateIntervalMs)
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
                    trackDuration > fadeOutDurationMillis
                ) {
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
        Log.d(TAG, "🔊 Service onCreate called")

        try {
            // Create audio attributes for primary player - meditation track
            val primaryAudioAttributes = AudioAttributes.Builder()
                .setContentType(C.AUDIO_CONTENT_TYPE_SPEECH)  // Speech for meditation
                .setUsage(C.USAGE_MEDIA)
                .build()

            // Create audio attributes for background player - ambient sounds
            val backgroundAudioAttributes = AudioAttributes.Builder()
                .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)  // Music for background
                .setUsage(C.USAGE_GAME)  // Different usage to avoid focus conflicts
                .build()

            // Create primary player with its own load control
            val primaryLoadControl = DefaultLoadControl.Builder()
                .setBufferDurationsMs(
                    DefaultLoadControl.DEFAULT_MIN_BUFFER_MS,
                    DefaultLoadControl.DEFAULT_MAX_BUFFER_MS,
                    DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_MS,
                    DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS
                )
                .setPrioritizeTimeOverSizeThresholds(true)
                .build()

            primaryPlayer = ExoPlayer.Builder(this)
                .setAudioAttributes(
                    primaryAudioAttributes,
                    false
                )  // Don't handle focus automatically
                .setHandleAudioBecomingNoisy(true)
                .setWakeMode(C.WAKE_MODE_NETWORK)
                .setLoadControl(primaryLoadControl)
                .build().apply {
                    addListener(object : Player.Listener {
                        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                            if (playWhenReady) {
                                Log.d(
                                    TAG,
                                    "🔊 Player set to playWhenReady=true, requesting audio focus"
                                )
                                requestAudioFocus()

                                // 👉 Sync background to resume
                                if (backgroundSoundUri != null && !backgroundMusicPlayer.isPlaying) {
                                    Log.d(
                                        TAG,
                                        "🔊 Resuming background sound from playWhenReadyChanged"
                                    )
                                    playBackgroundSound()
                                }
                            } else {
                                Log.d(
                                    TAG,
                                    "🔊 Player set to playWhenReady=false, abandoning audio focus"
                                )
                                abandonAudioFocus()

                                // 👉 Sync background to pause
                                if (backgroundMusicPlayer.isPlaying) {
                                    Log.d(
                                        TAG,
                                        "🔊 Pausing background sound from playWhenReadyChanged"
                                    )
                                    backgroundMusicPlayer.pause()
                                }
                            }
                        }
                    })
                }
            Log.d(TAG, "🔊 Primary player initialized successfully")

            // Create background player with its own load control
            val backgroundLoadControl = DefaultLoadControl.Builder()
                .setBufferDurationsMs(
                    DefaultLoadControl.DEFAULT_MIN_BUFFER_MS,
                    DefaultLoadControl.DEFAULT_MAX_BUFFER_MS,
                    DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_MS,
                    DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS
                )
                .setPrioritizeTimeOverSizeThresholds(true)
                .build()

            backgroundMusicPlayer = ExoPlayer.Builder(this)
                .setAudioAttributes(
                    backgroundAudioAttributes,
                    false
                )  // Don't handle focus automatically
                .setHandleAudioBecomingNoisy(false)  // Don't respond to headphones disconnection
                .setWakeMode(C.WAKE_MODE_LOCAL)
                .setLoadControl(backgroundLoadControl)
                .build()
            Log.d(TAG, "🔊 Background music player initialized successfully")

            primaryPlayer.addListener(this)

            primaryMediaSession = MediaSession.Builder(this, primaryPlayer)
                .setId("MeditoAudioSession_${System.currentTimeMillis()}")
                .build()
            Log.d(TAG, "🔊 Media session created successfully")
            
            // Mark service as fully initialized
            isServiceFullyInitialized = true
            
            // Notify any waiting callbacks that service is ready
            readinessCallback?.invoke(true)
            readinessCallback = null
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error initializing players: ${e.message}")
            e.printStackTrace()
            
            // Notify any waiting callbacks of failure
            readinessCallback?.invoke(false)
            readinessCallback = null
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "🔊 Service onDestroy called")

        // First, ensure we've released audio focus
        if (hasAudioFocus) {
            Log.d(TAG, "🔊 Abandoning audio focus on destroy")
            abandonAudioFocus()
        }

        // Cancel any pending coroutines
        serviceJob.cancel()

        // Clean up on the main thread to avoid threading issues
        handler.post {
            try {
                Log.d(TAG, "🔊 Removing callbacks and stopping players")
                backgroundHandler.removeCallbacks(positionUpdateRunnable)

                if (::primaryPlayer.isInitialized) {
                    primaryPlayer.stop()
                    primaryPlayer.removeListener(this@AudioPlayerService)
                    primaryPlayer.release()
                }

                if (::backgroundMusicPlayer.isInitialized) {
                    backgroundMusicPlayer.stop()
                    backgroundMusicPlayer.release()
                }

                primaryMediaSession?.run {
                    player.release()
                    release()
                    primaryMediaSession = null
                }

                Log.d(TAG, "🔊 Service cleanup completed")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error during service cleanup: ${e.message}")
                e.printStackTrace()
            }
        }

        super.onDestroy()
    }

    override fun onPlayerStateChanged(isPlaying: Boolean, playbackState: Int) {
        Log.d(TAG, "🔊 Player state changed: isPlaying=$isPlaying, state=$playbackState")

        // Update notification to reflect current state
        updateNotification()
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        Log.d(TAG, "🔊 Playback state changed: $playbackState")

        if (playbackState == Player.STATE_READY && primaryPlayer.isPlaying) {
            // Similar to former onPlay - play background sound if it's set
            if (backgroundSoundUri != null) {
                playBackgroundSound()
            }
        } else if (playbackState == Player.STATE_IDLE ||
            (playbackState == Player.STATE_READY && !primaryPlayer.isPlaying)
        ) {
            // Similar to former onPause - pause background sound
            if (backgroundMusicPlayer.isPlaying) {
                backgroundMusicPlayer.pause()
            }
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
        Log.d(TAG, "🔊 Service onStartCommand called")
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
        Log.d(TAG, "🔊 Started foreground service with initial notification")

        // Check for required permissions
        if (!hasRequiredPermissions()) {
            Log.e(TAG, "❌ Missing required permissions, stopping service")
            stopSelf()
            return START_NOT_STICKY
        }

        super.onStartCommand(intent, flags, startId)

        // Move initialization off main thread
        CoroutineScope(Dispatchers.Default).launch {
            try {
                FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID)?.let { engine ->
                    Log.d(TAG, "🔊 Found Flutter engine in cache")
                    withContext(Dispatchers.Main) {
                        MeditoAudioServiceApi.setUp(
                            engine.dartExecutor.binaryMessenger,
                            this@AudioPlayerService
                        )
                        meditoAudioApi =
                            MeditoAudioServiceCallbackApi(engine.dartExecutor.binaryMessenger)
                        Log.d(TAG, "🔊 Set up API communication with Flutter")
                    }
                } ?: run {
                    Log.e(TAG, "❌ Flutter engine not found in cache!")
                }

                // Start position updates
                withContext(Dispatchers.Main) {
                    Log.d(TAG, "🔊 Starting position updates")
                    backgroundHandler.removeCallbacks(positionUpdateRunnable)
                    backgroundHandler.post(positionUpdateRunnable)
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error setting up service: ${e.message}")
                e.printStackTrace()
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
        Log.d(TAG, "🔊 playAudio called with URL: ${audioData.url}, trackId: ${audioData.track.id}")
        if (!isServiceFullyInitialized || !::primaryPlayer.isInitialized || !::backgroundMusicPlayer.isInitialized) {
            Log.e(TAG, "❌ Players not initialized or service not ready")
            return false
        }

        isCompletionHandled = false

        try {
            // Remember if background was playing
            val wasBackgroundPlaying = backgroundMusicPlayer.isPlaying

            // Stop any existing playback
            Log.d(TAG, "🔊 Stopping any existing primary playback")
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

            // Request audio focus before preparing (but don't stop background sound)
            requestAudioFocus()

            // Prepare and start playback
            primaryPlayer.prepare()
            primaryPlayer.play()

            Log.d(TAG, "🔊 Started primary audio playback")

            // Update notification
            updateNotification()

            // Start position updates
            backgroundHandler.removeCallbacks(positionUpdateRunnable)
            backgroundHandler.post(positionUpdateRunnable)

            // Restart background sound if it was playing before
            if (wasBackgroundPlaying && backgroundSoundUri != null && !backgroundMusicPlayer.isPlaying) {
                Log.d(TAG, "🔊 Restarting background sound that was playing before")
                playBackgroundSound()
            }

            return true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in playAudio: ${e.message}")
            e.printStackTrace()
            return false
        }
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
            Log.d(TAG, "🔊 No background sound URI set - skipping playback")
            return
        }

        try {
            Log.d(TAG, "🔊 Setting up background sound: $backgroundSoundUri")

            // First ensure we've stopped any existing playback
            backgroundMusicPlayer.stop()
            backgroundMusicPlayer.clearMediaItems()
            Log.d(TAG, "🔊 Cleared existing background playback")

            val backgroundMediaItem = MediaItem.Builder()
                .setUri(backgroundSoundUri)
                .build()

            // Set up the background player
            backgroundMusicPlayer.repeatMode = Player.REPEAT_MODE_ONE
            backgroundMusicPlayer.setMediaItem(backgroundMediaItem)
            backgroundMusicPlayer.prepare()

            // Start playing once prepared
            backgroundMusicPlayer.play()

            Log.d(TAG, "🔊 Started background playback")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error playing background sound: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun pauseBackgroundSound() {
        backgroundMusicPlayer.pause()
    }

    override fun setBackgroundSound(uri: String?) {
        Log.d(TAG, "🔊 setBackgroundSound called with URI: $uri")

        // Always stop the current background sound first
        try {
            if (::backgroundMusicPlayer.isInitialized) {
                backgroundMusicPlayer.stop()
                Log.d(TAG, "🔊 Stopped current background sound")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping background sound: ${e.message}")
        }

        // Now set the new URI
        this.backgroundSoundUri = uri

        if (uri == null) {
            Log.d(TAG, "🔊 Background sound cleared")
        } else {
            Log.d(TAG, "🔊 Background sound URI set to: $uri")
        }
    }

    override fun stopBackgroundSound() {
        try {
            Log.d(TAG, "🔊 Stopping background sound")
            if (::backgroundMusicPlayer.isInitialized) {
                backgroundMusicPlayer.stop()
                // Don't clear the URI - that should be done by setBackgroundSound(null)
                Log.d(TAG, "🔊 Background sound stopped successfully")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping background sound: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun setBackgroundSoundVolume(volume: Double) {
        if (!isServiceFullyInitialized) {
            Log.d(TAG, "⚠️ setBackgroundSoundVolume called before service fully initialized")
            throw IllegalStateException("Service not fully initialized")
        }
        this.backgroundMusicVolume = volume.toFloat()
        if (::backgroundMusicPlayer.isInitialized) {
            backgroundMusicPlayer.volume = this.backgroundMusicVolume
        }
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
        Log.d(TAG, "🔊 playPauseAudio called")
        try {
            isCompletionHandled = false
            if (primaryPlayer.isPlaying) {
                Log.d(TAG, "🔊 Pausing primary player")
                primaryPlayer.pause()
                // Also pause background sound
                if (backgroundMusicPlayer.isPlaying) {
                    Log.d(TAG, "🔊 Also pausing background sound")
                    backgroundMusicPlayer.pause()
                }
            } else {
                Log.d(TAG, "🔊 Playing primary player")

                // Request audio focus before playing
                requestAudioFocus()

                // Play regardless of audio focus state
                primaryPlayer.play()

                // If background sound was previously playing, resume it
                if (backgroundSoundUri != null) {
                    Log.d(TAG, "🔊 Resuming background sound if available")
                    playBackgroundSound()
                }

                Log.d(TAG, "🔊 Primary player playback started")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in playPauseAudio: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun requestAudioFocus() {
        try {
            if (hasAudioFocus) {
                Log.d(TAG, "🔊 Already have audio focus, not requesting again")
                return
            }

            Log.d(TAG, "🔊 Requesting audio focus")
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

            val audioAttributes = android.media.AudioAttributes.Builder()
                .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()

            val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(audioAttributes)
                .setOnAudioFocusChangeListener { focusChange ->
                    Log.d(TAG, "🔊 Audio focus changed to: $focusChange")
                    when (focusChange) {
                        AudioManager.AUDIOFOCUS_GAIN -> {
                            Log.d(TAG, "🔊 Audio focus GAINED")
                            hasAudioFocus = true
                            if (::primaryPlayer.isInitialized) {
                                // Restore volume
                                primaryPlayer.volume = 1f

                                // Resume playback if we should be playing
                                if (primaryPlayer.playWhenReady && !primaryPlayer.isPlaying &&
                                    primaryPlayer.playbackState != Player.STATE_IDLE &&
                                    primaryPlayer.playbackState != Player.STATE_ENDED
                                ) {
                                    Log.d(TAG, "🔊 Resuming playback after gaining focus")
                                    primaryPlayer.play()
                                }
                            }
                        }

                        AudioManager.AUDIOFOCUS_LOSS -> {
                            Log.d(TAG, "🔊 Audio focus LOST")
                            hasAudioFocus = false
                            // Do NOT pause the primary player on audio focus loss
                            // Just lower the volume to be polite to other apps
                            if (::primaryPlayer.isInitialized && primaryPlayer.isPlaying) {
                                primaryPlayer.volume = 0.3f
                            }
                        }

                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                            Log.d(TAG, "🔊 Audio focus LOST TRANSIENT")
                            // Do NOT pause the primary player on transient focus loss
                            // Just lower the volume to be polite to other apps
                            if (::primaryPlayer.isInitialized && primaryPlayer.isPlaying) {
                                primaryPlayer.volume = 0.3f
                            }
                        }

                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                            Log.d(TAG, "🔊 Audio focus LOST TRANSIENT (CAN DUCK)")
                            if (::primaryPlayer.isInitialized) {
                                Log.d(TAG, "🔊 Ducking volume due to transient focus loss")
                                primaryPlayer.volume = 0.2f
                            }
                        }
                    }
                }
                .build()

            val result = audioManager.requestAudioFocus(focusRequest)
            hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED

            Log.d(
                TAG,
                "🔊 Audio focus request result: $result (${if (hasAudioFocus) "GRANTED" else "DENIED"})"
            )
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error requesting audio focus: ${e.message}")
            e.printStackTrace()
        }
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

    private fun syncBackgroundWithPrimaryState() {
        if (!::backgroundMusicPlayer.isInitialized || backgroundSoundUri == null) {
            return
        }

        try {
            // If primary is playing, ensure background is playing too
            if (primaryPlayer.isPlaying) {
                if (!backgroundMusicPlayer.isPlaying) {
                    Log.d(TAG, "🔊 Syncing background sound - playing")
                    playBackgroundSound()
                }
            }
            // If primary is paused/stopped, pause background too
            else if (backgroundMusicPlayer.isPlaying) {
                Log.d(TAG, "🔊 Syncing background sound - pausing")
                backgroundMusicPlayer.pause()
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error syncing background with primary: ${e.message}")
        }
    }

    // Check if service is fully initialized and components are ready
    fun isReady(): Boolean {
        return isServiceFullyInitialized && ::primaryPlayer.isInitialized && ::backgroundMusicPlayer.isInitialized
    }
    
    // Allow setting a callback to be notified when service is ready
    fun checkReadiness(callback: (Boolean) -> Unit) {
        if (isServiceFullyInitialized) {
            callback(true)
        } else {
            readinessCallback = callback
        }
    }

    companion object {
        const val CHANNEL_ID = "medito_reminder_channel"
        const val NOTIFICATION_ID = 101011
        private const val TAG = "MeditoAudioService"
        const val ACTION_BIND_SERVICE = "meditofoundation.medito.BIND_SERVICE"
    }
}
