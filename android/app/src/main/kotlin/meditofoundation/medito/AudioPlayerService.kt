@file:UnstableApi

package meditofoundation.medito

import android.app.Notification
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.NotificationUtil
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.MediaStyleNotificationHelper
import io.flutter.embedding.engine.FlutterEngineCache
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.SupervisorJob
import android.media.AudioManager
import android.media.AudioFocusRequest
import android.content.Context
import android.os.Binder
import android.os.IBinder
import android.content.pm.ServiceInfo
import android.os.Build
import android.app.ForegroundServiceStartNotAllowedException
import android.app.PendingIntent
import android.view.KeyEvent
import meditofoundation.medito.pigeon.*

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
    private var flutterEngine: io.flutter.embedding.engine.FlutterEngine? = null
    private lateinit var audioManager: AudioManager
    private var currentRepeatMode: RepeatMode = RepeatMode.NONE

    // Result callback when service is ready
    private var readinessCallback: ((Boolean) -> Unit)? = null

    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.Main + serviceJob)
    private val backgroundScope = CoroutineScope(Dispatchers.Default + serviceJob)
    private var positionUpdateJob: Job? = null
    private val fadeOutDurationMillis = 10000
    private val handler = Handler(Looper.myLooper() ?: Looper.getMainLooper())
    @Volatile
    private var isUpdatingPlaybackState = false

    private fun startPositionUpdates() {
        positionUpdateJob?.cancel()
        positionUpdateJob = backgroundScope.launch {
            while (isActive) {
                updatePlaybackState()
                delay(1000) // 1 second interval
            }
        }
    }

    private fun stopPositionUpdates() {
        positionUpdateJob?.cancel()
    }

    private suspend fun updatePlaybackState() {
        if (!::primaryPlayer.isInitialized) return
        
        // Skip if previous update is still in progress to prevent accumulation
        if (isUpdatingPlaybackState) {
            return
        }

        try {
            isUpdatingPlaybackState = true
            
            // ExoPlayer methods should be called on main thread for thread safety
            val state = withContext(Dispatchers.Main) {
                if (!::primaryPlayer.isInitialized) return@withContext null
                
                PlaybackState(
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
                            fileId = mediaItem.mediaMetadata.extras?.getString(KEY_FILE_ID) ?: "",
                            description = mediaItem.mediaMetadata.description?.toString()
                                ?: "",
                            imageUrl = mediaItem.mediaMetadata.artworkUri?.toString() ?: "",
                            artist = mediaItem.mediaMetadata.artist?.toString() ?: "",
                            artistUrl = mediaItem.mediaMetadata.extras?.getString(KEY_ARTIST_URL),
                        )
                    } ?: Track(id = "", title = "", fileId = "", description = "", imageUrl = "", artist = null, artistUrl = null)
                )
            } ?: return

            // Apply background sound volume on main thread (touches ExoPlayer)
            withContext(Dispatchers.Main) {
                applyBackgroundSoundVolume(state.duration, state.position)
            }

            // Pigeon channel communication - already async/non-blocking
            // Post to main thread handler to ensure thread safety for callback
            val api = meditoAudioApi
            if (api != null) {
                handler.post {
                    api.updatePlaybackState(state) {
                        if (state.isCompleted && !isCompletionHandled) {
                            isCompletionHandled = true
                            handleTrackCompletion(state)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error updating playback state: ${e.message}")
        } finally {
            isUpdatingPlaybackState = false
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
            fileId = state.track.fileId,
            guideId = state.track.artist,
            timestamp = System.currentTimeMillis()
        )
    }

    private fun handleTrackCompletionFromPlayer() {
        saveAndSendCompletionData(createCompletionDataFromPlayer())
    }

    // Builds completion data directly from the player. Used by the native
    // STATE_ENDED handler, which must not depend on a Dart-provided PlaybackState.
    private fun createCompletionDataFromPlayer(): CompletionData {
        val mediaItem = primaryPlayer.currentMediaItem
        val metadata = mediaItem?.mediaMetadata
        return CompletionData(
            trackId = mediaItem?.mediaId ?: "",
            duration = primaryPlayer.duration.takeIf { it != C.TIME_UNSET } ?: 0L,
            fileId = metadata?.extras?.getString(KEY_FILE_ID) ?: "",
            guideId = metadata?.artist?.toString(),
            timestamp = System.currentTimeMillis()
        )
    }

    private fun saveAndSendCompletionData(completionData: CompletionData) {
        // Persist first: completion is replayed by MainActivity on next launch if
        // the app is killed before Dart records it, so nothing is lost.
        SharedPreferencesManager.saveCompletionData(this@AudioPlayerService, completionData)

        // Tear down the foreground service + notification immediately and natively.
        // Teardown must NOT depend on the Dart reply below — on devices that freeze
        // the app in the background (e.g. MIUI/Xiaomi) the reply may never arrive,
        // which previously left the player notification stuck until reboot.
        finishPlayback()

        // Fire-and-forget the analytics callback. If it completes we can clear the
        // persisted record; if it doesn't, the replay path handles it next launch.
        CoroutineScope(Dispatchers.Main).launch {
            meditoAudioApi?.handleCompletedTrack(completionData) { result ->
                if (result.isSuccess) {
                    SharedPreferencesManager.clearCompletionData(this@AudioPlayerService)
                }
            }
        }
    }

    private fun finishPlayback() {
        stopPositionUpdates()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun applyBackgroundSoundVolume(trackDuration: Long, currentPosition: Long) {
        try {
            // Only apply fade if background sound is set, initialized, and volume is set
            if (backgroundSoundUri == null || 
                !::backgroundMusicPlayer.isInitialized || 
                backgroundMusicVolume <= 0.0F) {
                return
            }

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
            if (::backgroundMusicPlayer.isInitialized) {
                backgroundMusicPlayer.volume = backgroundMusicVolume
            }
        }
    }

    private var playbackState: PlaybackState? = null

    private fun createMeditationAudioAttributes(): AudioAttributes {
        return AudioAttributes.Builder()
            .setContentType(C.AUDIO_CONTENT_TYPE_SPEECH)
            .setUsage(C.USAGE_MEDIA)
            .build()
    }

    private fun createBackgroundAudioAttributes(): AudioAttributes {
        return AudioAttributes.Builder()
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
            .setUsage(C.USAGE_GAME)
            .build()
    }

    private fun createLoadControl(): DefaultLoadControl {
        return DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                DefaultLoadControl.DEFAULT_MIN_BUFFER_MS,
                DefaultLoadControl.DEFAULT_MAX_BUFFER_MS,
                DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_MS,
                DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS
            )
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()
    }

    private fun createPrimaryMediaSourceFactory(): DefaultMediaSourceFactory {
        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
            .setUserAgent("Medito-Android")
            .setConnectTimeoutMs(15_000)
            .setReadTimeoutMs(30_000)
            .setAllowCrossProtocolRedirects(true)

        return DefaultMediaSourceFactory(this)
            .setDataSourceFactory(DefaultDataSource.Factory(this, httpDataSourceFactory))
    }

    private fun createMediaSession(): MediaSession {
        return MediaSession.Builder(this, primaryPlayer)
            .setId("MeditoAudioSession_${System.currentTimeMillis()}")
            .build()
    }

    override fun onCreate() {
        super.onCreate()
        println("🔊 [AudioPlayerService] onCreate called")
        Log.d(TAG, "🔊 Service onCreate called")
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // Flutter Engine and API setup is handled in onStartCommand
        // flutterEngine = FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID) ?: run { ... }

        try {
            primaryPlayer = ExoPlayer.Builder(this)
                .setAudioAttributes(
                    createMeditationAudioAttributes(),
                    false
                )  // Don't handle focus automatically
                .setHandleAudioBecomingNoisy(true)
                .setWakeMode(C.WAKE_MODE_NETWORK)
                .setLoadControl(createLoadControl())
                .setMediaSourceFactory(createPrimaryMediaSourceFactory())
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

            backgroundMusicPlayer = ExoPlayer.Builder(this)
                .setAudioAttributes(
                    createBackgroundAudioAttributes(),
                    false
                )  // Don't handle focus automatically
                .setHandleAudioBecomingNoisy(false)  // Don't respond to headphones disconnection
                .setWakeMode(C.WAKE_MODE_LOCAL)
                .setLoadControl(createLoadControl())
                .build()
            Log.d(TAG, "🔊 Background music player initialized successfully")

            primaryPlayer.addListener(this)

            primaryMediaSession = createMediaSession()
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
        println("🔊 [AudioPlayerService] onCreate finished")
    }

    override fun onDestroy() {
        Log.d(TAG, "🔊 Service onDestroy called")

        // Always remove the foreground notification on teardown, even when the
        // service dies via a path that didn't call finishPlayback()/stopAudio()
        // (e.g. the OS killing a background-frozen service). Without this an
        // orphaned, un-dismissable media notification could linger until reboot.
        try {
            clearNotification()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error clearing notification in onDestroy: ${e.message}")
        }

        // First, ensure we've released audio focus
        if (hasAudioFocus) {
            Log.d(TAG, "🔊 Abandoning audio focus on destroy")
            abandonAudioFocus()
        }

        // Cancel any pending coroutines
        serviceJob.cancel()
        stopPositionUpdates()

        // Clean up on the main thread to avoid threading issues
        handler.post {
            try {
                Log.d(TAG, "🔊 Removing callbacks and stopping players")
                
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

    override fun onPlayerError(error: PlaybackException) {
        Log.e(TAG, "❌ Player error: ${error.errorCodeName} — ${error.message}", error)
        if (!::primaryPlayer.isInitialized) return
        val resumePos = primaryPlayer.currentPosition.takeIf { it > 0 } ?: 0L
        val duration = primaryPlayer.duration.takeIf { it != C.TIME_UNSET } ?: -1L
        val api = meditoAudioApi
        if (api != null) {
            handler.post {
                api.reportPlayerError(
                    error.errorCodeName,
                    error.message ?: "unknown",
                    resumePos,
                    duration,
                ) { /* fire-and-forget */ }
            }
        }
        primaryPlayer.prepare()
        if (resumePos > 0) primaryPlayer.seekTo(resumePos)
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        Log.d(TAG, "🔊 Playback state changed: $playbackState")

        if (playbackState == Player.STATE_ENDED) {
            // Drive completion + notification teardown natively and immediately.
            // This fires regardless of whether the Flutter engine is alive, unlike
            // the Dart-reply-gated poll path in updatePlaybackState(). Skipping the
            // updateNotification() below avoids re-posting the stuck "ended" card.
            if (!isCompletionHandled) {
                isCompletionHandled = true
                handleTrackCompletionFromPlayer()
            }
            return
        }

        if (playbackState == Player.STATE_READY || playbackState == Player.STATE_IDLE) {
            syncBackgroundWithPrimaryState()
        }

        // Update notification to reflect current state
        updateNotification()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Only stop service if not playing
        if (!primaryPlayer.isPlaying) {
            serviceScope.launch {
                // Session analytics: the user swiped the app away while the
                // track was paused — i.e. abandoned it. Push one last position
                // snapshot to Dart before teardown so AudioSessionTracker has
                // the freshest position to attribute the audio_session_abandoned
                // event (fired in Dart, or replayed on next launch from the
                // persisted record). Skipped if the track already completed —
                // that path reports its own event. Mirrors how completion is
                // surfaced to Dart rather than firing Firebase from native code.
                if (!isCompletionHandled) {
                    try {
                        updatePlaybackState()
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error pushing final playback state on task removal: ${e.message}")
                    }
                }
                stopPositionUpdates()
                clearNotification()
                resetPrimaryQueue()
                resetBackgroundQueue()
                stopSelf()
            }
        }
    }

    override fun stopService(name: Intent?): Boolean {
        return super.stopService(name)
    }

    private fun clearNotification() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        publishNotification(null)
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return primaryMediaSession
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "🔊 Service onStartCommand called with action: ${intent?.action}")
        
        // Handle media button actions from notification
        when (intent?.action) {
            ACTION_PLAY_PAUSE -> {
                Log.d(TAG, "🔊 Handling play/pause action from notification")
                playPauseAudio()
                return START_STICKY
            }
            ACTION_SKIP_FORWARD -> {
                Log.d(TAG, "🔊 Handling skip forward action from notification")
                skip10SecondsForward()
                return START_STICKY
            }
            ACTION_SKIP_BACKWARD -> {
                Log.d(TAG, "🔊 Handling skip backward action from notification")
                skip10SecondsBackward()
                return START_STICKY
            }
        }
        
        // Create and show notification immediately
        try {
            val notification = createInitialNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            Log.d(TAG, "🔊 Started foreground service with initial notification")
        } catch (e: ForegroundServiceStartNotAllowedException) {
            // This exception only occurs on Android 12+ (API 31+) when trying to start
            // a foreground service from the background
            Log.e(TAG, "❌ ForegroundServiceStartNotAllowedException: ${e.message}")
            Log.w(TAG, "⚠️ Cannot start foreground service from background, stopping service")
            // Stop the service since we can't run as foreground
            stopSelf()
            return START_NOT_STICKY
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting foreground service: ${e.message}")
            e.printStackTrace()
            // Try to continue anyway if it's not a critical error
        }

        // Call super after starting foreground
        super.onStartCommand(intent, flags, startId)

        // Check for required permissions
        if (!hasRequiredPermissions()) {
            Log.e(TAG, "❌ Missing required permissions, stopping service")
            stopSelf()
            return START_NOT_STICKY
        }

        // Move initialization off main thread
        CoroutineScope(Dispatchers.Default).launch {
            try {
                FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID)?.let { engine ->
                    Log.d(TAG, "🔊 Found Flutter engine in cache")
                    flutterEngine = engine // Save engine reference
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
                    startPositionUpdates()
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error setting up service: ${e.message}")
                e.printStackTrace()
            }
        }

        return START_STICKY
    }

    private fun createInitialNotification(): Notification {
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
        return initialNotification
    }

    private fun hasRequiredPermissions(): Boolean {
        // Add any media playback related permission checks here
        // For example, checking audio focus permissions if needed
        return true
    }

    private fun buildPrimaryMediaItem(audioData: AudioData): MediaItem {
        return MediaItem.Builder()
            .setUri(audioData.url)
            .setMediaId(audioData.track.id)
            .setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle(audioData.track.title)
                    .setArtist(audioData.track.artist)
                    .setDescription(audioData.track.description)
                    .setArtworkUri(audioData.track.imageUrl?.let { Uri.parse(it) })
                    .setExtras(android.os.Bundle().apply {
                        putString(KEY_ARTIST_URL, audioData.track.artistUrl)
                        putString(KEY_FILE_ID, audioData.track.fileId)
                    })
                    .build()
            )
            .build()
    }

    private fun resetPrimaryQueue() {
        primaryPlayer.stop()
        primaryPlayer.clearMediaItems()
    }

    private fun resetBackgroundQueue() {
        backgroundMusicPlayer.stop()
        backgroundMusicPlayer.clearMediaItems()
    }

    private fun configurePrimaryPlaylist(mediaItem: MediaItem, mode: RepeatMode) {
        when (mode) {
            RepeatMode.NONE -> {
                primaryPlayer.setMediaItem(mediaItem)
                primaryPlayer.repeatMode = Player.REPEAT_MODE_OFF
            }
            RepeatMode.ONCE -> {
                primaryPlayer.addMediaItem(mediaItem)
                primaryPlayer.addMediaItem(mediaItem)
                primaryPlayer.repeatMode = Player.REPEAT_MODE_OFF
                Log.d(TAG, "🔊 Added media item twice for repeat once mode")
            }
            RepeatMode.INFINITE -> {
                primaryPlayer.setMediaItem(mediaItem)
                primaryPlayer.repeatMode = Player.REPEAT_MODE_ONE
            }
        }
    }

    private fun ensureMediaSession() {
        if (primaryMediaSession != null) return

        Log.w(TAG, "⚠️ MediaSession is null, recreating it")
        primaryMediaSession = createMediaSession()
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
            resetPrimaryQueue()

            // Apply current repeat mode
            configurePrimaryPlaylist(buildPrimaryMediaItem(audioData), currentRepeatMode)

            // Request audio focus before preparing (but don't stop background sound)
            val audioFocusGranted = requestAudioFocus()
            
            // On Android 16+, continue even if audio focus is denied initially
            // The system may grant it later, and we want to attempt playback
            if (!audioFocusGranted) {
                Log.w(TAG, "⚠️ Audio focus not granted initially, but continuing with playback attempt")
            }

            // Ensure MediaSession is ready (important for Android 16+)
            ensureMediaSession()
            
            // Prepare the player
            primaryPlayer.prepare()
            
            // Helper function to start playback once ready
            val startPlayback = {
                // Ensure we still have audio focus or request it again
                if (!hasAudioFocus) {
                    requestAudioFocus()
                }
                
                // Start playback
                primaryPlayer.play()
                
                // Update notification
                updateNotification()
                
                // Start position updates
                startPositionUpdates()
                
                // Restart background sound if it was playing before
                if (wasBackgroundPlaying && backgroundSoundUri != null && !backgroundMusicPlayer.isPlaying) {
                    Log.d(TAG, "🔊 Restarting background sound that was playing before")
                    playBackgroundSound()
                }
            }
            
            // Check if player is already ready
            if (primaryPlayer.playbackState == Player.STATE_READY) {
                Log.d(TAG, "🔊 Player already ready, starting playback immediately")
                startPlayback()
            } else {
                // Wait for player to be ready before playing (important for Android 16+)
                // Use a listener to start playback once ready
                val playbackListener = object : Player.Listener {
                    private var isHandled = false
                    
                    override fun onPlaybackStateChanged(state: Int) {
                        if (state == Player.STATE_READY && !isHandled) {
                            isHandled = true
                            Log.d(TAG, "🔊 Player is ready, starting playback")
                            primaryPlayer.removeListener(this)
                            startPlayback()
                        } else if (state == Player.STATE_IDLE || state == Player.STATE_ENDED) {
                            if (!isHandled) {
                                isHandled = true
                                primaryPlayer.removeListener(this)
                            }
                        }
                    }
                }
                
                primaryPlayer.addListener(playbackListener)
            }

            Log.d(TAG, "🔊 Started primary audio playback preparation")

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
                    showNotification(createNotificationBuilder(title, artist, artworkBitmap).build())
                }
            } catch (e: Exception) {
                e.printStackTrace()
                withContext(Dispatchers.Main) {
                    showNotification(createNotificationBuilder(title, artist, null).build())
                }
            }
        }
    }

    private fun showNotification(newNotification: Notification) {
        notification = newNotification
        publishNotification(notification)
    }

    private fun publishNotification(newNotification: Notification?) {
        NotificationUtil.setNotification(
            this@AudioPlayerService,
            NOTIFICATION_ID,
            newNotification
        )
    }

    private fun createNotificationBuilder(
        title: String,
        artist: String,
        artworkBitmap: Bitmap?
    ): NotificationCompat.Builder {
        val isPlaying = if (::primaryPlayer.isInitialized) primaryPlayer.isPlaying else false

        val builder = NotificationCompat.Builder(this@AudioPlayerService, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(artist)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setLargeIcon(artworkBitmap)
            .setSilent(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        // Add explicit media control actions for older Android versions
        // These are required for pre-Android 8 devices to show controls on lock screen
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        // Skip backward action
        builder.addAction(
            NotificationCompat.Action(
                R.drawable.ic_skip_backward,
                "Skip Backward",
                createMediaButtonPendingIntent(KeyEvent.KEYCODE_MEDIA_PREVIOUS, pendingIntentFlags)
            )
        )

        // Play/Pause action
        val playPauseIcon = if (isPlaying) R.drawable.ic_pause else R.drawable.ic_play
        val playPauseTitle = if (isPlaying) "Pause" else "Play"
        builder.addAction(
            NotificationCompat.Action(
                playPauseIcon,
                playPauseTitle,
                createMediaButtonPendingIntent(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, pendingIntentFlags)
            )
        )

        // Skip forward action
        builder.addAction(
            NotificationCompat.Action(
                R.drawable.ic_skip_forward,
                "Skip Forward",
                createMediaButtonPendingIntent(KeyEvent.KEYCODE_MEDIA_NEXT, pendingIntentFlags)
            )
        )

        // Apply MediaStyle with actions shown in compact view
        primaryMediaSession?.let { session ->
            builder.setStyle(
                MediaStyleNotificationHelper.MediaStyle(session)
                    .setShowActionsInCompactView(0, 1, 2)  // Show all 3 actions in compact view
            )
        }

        return builder
    }

    private fun createMediaButtonPendingIntent(keyCode: Int, flags: Int): PendingIntent {
        val action = when (keyCode) {
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> ACTION_PLAY_PAUSE
            KeyEvent.KEYCODE_MEDIA_PREVIOUS -> ACTION_SKIP_BACKWARD
            KeyEvent.KEYCODE_MEDIA_NEXT -> ACTION_SKIP_FORWARD
            else -> return PendingIntent.getService(this, keyCode, Intent(this, AudioPlayerService::class.java), flags)
        }

        val intent = Intent(this, AudioPlayerService::class.java).apply {
            this.action = action
        }
        return PendingIntent.getService(this, keyCode, intent, flags)
    }

    override fun playBackgroundSound() {
        if (backgroundSoundUri == null) {
            Log.d(TAG, "🔊 No background sound URI set - skipping playback")
            return
        }

        try {
            Log.d(TAG, "🔊 Setting up background sound: $backgroundSoundUri")

            // First ensure we've stopped any existing playback
            resetBackgroundQueue()
            Log.d(TAG, "🔊 Cleared existing background playback")

            val backgroundMediaItem = MediaItem.Builder()
                .setUri(backgroundSoundUri)
                .build()

            // Set up the background player
            backgroundMusicPlayer.repeatMode = Player.REPEAT_MODE_ONE
            backgroundMusicPlayer.setMediaItem(backgroundMediaItem)
            backgroundMusicPlayer.prepare()

            // Ensure volume is set before playing
            if (backgroundMusicVolume > 0.0F) {
                backgroundMusicPlayer.volume = backgroundMusicVolume
            }

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
        seekBy(SEEK_INTERVAL_MS)
    }

    override fun skip10SecondsBackward() {
        seekBy(-SEEK_INTERVAL_MS)
    }

    private fun seekBy(deltaMs: Long) {
        if (!::primaryPlayer.isInitialized) return

        val currentPosition = primaryPlayer.currentPosition
        val targetPosition = if (deltaMs > 0) {
            val duration = primaryPlayer.duration
            if (duration == C.TIME_UNSET) return
            minOf(currentPosition + deltaMs, duration)
        } else {
            maxOf(currentPosition + deltaMs, 0L)
        }

        primaryPlayer.seekTo(targetPosition)
    }

    override fun setRepeatMode(mode: RepeatMode) {
        Log.d(TAG, "🔊 Setting repeat mode to: $mode")
        currentRepeatMode = mode
        
        if (::primaryPlayer.isInitialized) {
            val currentMediaItem = primaryPlayer.currentMediaItem
            if (currentMediaItem == null) {
                Log.d(TAG, "🔊 No media item currently loaded, repeat mode will be applied when media is loaded")
                return
            }

            // Get current position to restore after rebuilding playlist
            val currentPosition = primaryPlayer.currentPosition
            val wasPlaying = primaryPlayer.isPlaying

            // Rebuild playlist based on repeat mode
            resetPrimaryQueue()
            configurePrimaryPlaylist(currentMediaItem, mode)

            // Restore playback state
            primaryPlayer.prepare()
            if (wasPlaying) {
                primaryPlayer.seekTo(currentPosition)
                primaryPlayer.play()
            } else {
                primaryPlayer.seekTo(currentPosition)
            }
        }
    }

    override fun stopAudio() {
        isCompletionHandled = false
        primaryPlayer.stop()
        backgroundMusicPlayer.stop()
        clearNotification()
        stopPositionUpdates()
    }

    override fun playPauseAudio() {
        Log.d(TAG, "🔊 playPauseAudio called")
        try {
            isCompletionHandled = false
            
            // Check if player is initialized and in a valid state
            if (!::primaryPlayer.isInitialized) {
                Log.e(TAG, "❌ Primary player not initialized")
                return
            }
            
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
                
                // Check player state before attempting to play
                val playbackState = primaryPlayer.playbackState
                if (playbackState == Player.STATE_IDLE || playbackState == Player.STATE_ENDED) {
                    Log.w(TAG, "⚠️ Player is in $playbackState state, cannot play. Need to prepare first.")
                    return
                }

                // Request audio focus before playing
                requestAudioFocus()

                // Only play if player is in a ready state
                if (playbackState == Player.STATE_READY || playbackState == Player.STATE_BUFFERING) {
                    primaryPlayer.play()
                    
                    // If background sound was previously playing, resume it
                    if (backgroundSoundUri != null) {
                        Log.d(TAG, "🔊 Resuming background sound if available")
                        playBackgroundSound()
                    }

                    Log.d(TAG, "🔊 Primary player playback started")
                } else {
                    Log.w(TAG, "⚠️ Player not ready (state: $playbackState), waiting for STATE_READY")
                    // Add listener to play when ready
                    val playListener = object : Player.Listener {
                        private var isHandled = false
                        
                        override fun onPlaybackStateChanged(state: Int) {
                            if (state == Player.STATE_READY && !isHandled) {
                                isHandled = true
                                primaryPlayer.removeListener(this)
                                primaryPlayer.play()
                                
                                if (backgroundSoundUri != null) {
                                    playBackgroundSound()
                                }
                                
                                Log.d(TAG, "🔊 Primary player playback started after becoming ready")
                            }
                        }
                    }
                    primaryPlayer.addListener(playListener)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in playPauseAudio: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun requestAudioFocus(): Boolean {
        try {
            if (hasAudioFocus) {
                Log.d(TAG, "🔊 Already have audio focus, not requesting again")
                return true
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
            
            return hasAudioFocus
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error requesting audio focus: ${e.message}")
            e.printStackTrace()
            return false
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
        if (!::primaryPlayer.isInitialized || !::backgroundMusicPlayer.isInitialized) {
            return
        }

        try {
            // If primary is playing, ensure background is playing too
            if (primaryPlayer.isPlaying && backgroundSoundUri != null) {
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

    override fun onBind(intent: Intent?): IBinder? {
        println("🔊 [AudioPlayerService] onBind called with intent action: ${intent?.action}")
        if (intent?.action == ACTION_BIND_SERVICE) {
            println("🔊 [AudioPlayerService] Returning binder")
            return binder
        }
        println("🔊 [AudioPlayerService] Calling super.onBind")
        return super.onBind(intent)
    }

    companion object {
        const val CHANNEL_ID = "medito_reminder_channel"
        const val NOTIFICATION_ID = 101011
        private const val TAG = "MeditoAudioService"
        const val ACTION_BIND_SERVICE = "meditofoundation.medito.BIND_SERVICE"
        const val ACTION_PLAY_PAUSE = "meditofoundation.medito.ACTION_PLAY_PAUSE"
        const val ACTION_SKIP_FORWARD = "meditofoundation.medito.ACTION_SKIP_FORWARD"
        const val ACTION_SKIP_BACKWARD = "meditofoundation.medito.ACTION_SKIP_BACKWARD"
        private const val KEY_ARTIST_URL = "artistUrl"
        private const val KEY_FILE_ID = "fileId"
        private const val SEEK_INTERVAL_MS = 15_000L
    }
}
