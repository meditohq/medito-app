package meditofoundation.medito

import MeditoAndroidAudioServiceManager
import MeditoAudioServiceCallbackApi
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.media3.common.util.UnstableApi
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugins.GeneratedPluginRegistrant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

@UnstableApi
class MainActivity : FlutterFragmentActivity(), MeditoAndroidAudioServiceManager {

    private var meditoAudioApi: MeditoAudioServiceCallbackApi? = null
    private val activityJob = SupervisorJob()
    private val activityScope = CoroutineScope(Dispatchers.Main + activityJob)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        FlutterEngineCache
            .getInstance()
            .put(ENGINE_ID, flutterEngine)
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MeditoAndroidAudioServiceManager.setUp(flutterEngine.dartExecutor.binaryMessenger, this)

        meditoAudioApi = MeditoAudioServiceCallbackApi(flutterEngine.dartExecutor.binaryMessenger)
        checkAndSendCompletionData()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    override fun onResume() {
        super.onResume()
        checkAndSendCompletionData()
    }

    override fun onDestroy() {
        super.onDestroy()
        activityJob.cancel()
    }

    private fun createNotificationChannels() {
        createAudioServiceNotificationChannel()
        createReminderNotificationChannel()
        createNewsNotificationChannel()
        createFirebaseNotificationChannel()
    }

    private fun createAudioServiceNotificationChannel() {
        val channelName = "Meditation audio"
        val importance = NotificationManager.IMPORTANCE_LOW
        val channel = NotificationChannel(AudioPlayerService.CHANNEL_ID, channelName, importance).apply {
            description = "Notification for media control of meditation audio"
            setShowBadge(false)
            enableLights(false)
            enableVibration(false)
        }

        val notificationManager: NotificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
        
        println("Created audio service notification channel with ID: ${AudioPlayerService.CHANNEL_ID}")
    }

    private fun createNewsNotificationChannel() {
        val channelName = "News and Updates"
        val importance = NotificationManager.IMPORTANCE_HIGH
        val channel = NotificationChannel(NEWS_CHANNEL_ID, channelName, importance).apply {
            description = "Stay up-to-date with the latest news and updates from Medito"
        }

        val notificationManager: NotificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }

    private fun createReminderNotificationChannel() {
        val channelName = "Reminders"
        val importance = NotificationManager.IMPORTANCE_HIGH
        val channel = NotificationChannel(REMINDER_CHANNEL_ID, channelName, importance).apply {
            description = "Notification for meditation reminders"
        }

        val notificationManager: NotificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }

    private fun createFirebaseNotificationChannel() {
        val channelName = "Medito Notifications"
        val importance = NotificationManager.IMPORTANCE_HIGH
        val channel = NotificationChannel("high_importance_channel", channelName, importance).apply {
            description = "Stay up-to-date with the latest from Medito"
            enableLights(true)
            enableVibration(true)
            setShowBadge(false)
        }

        val notificationManager: NotificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }

    override fun startService() {
        // Ensure notification channel exists before starting service
        createAudioServiceNotificationChannel()
        val intent = Intent(this, AudioPlayerService::class.java)
        
        // Use the appropriate method based on Android version
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }

        // Log successful service start attempt
        println("🔊 Service start requested")
    }

    override fun isServiceReady(callback: (Result<Boolean>) -> Unit) {
        val intent = Intent(this, AudioPlayerService::class.java)
        intent.action = AudioPlayerService.ACTION_BIND_SERVICE
        val serviceConnection = object : android.content.ServiceConnection {
            override fun onServiceConnected(name: android.content.ComponentName?, service: android.os.IBinder?) {
                try {
                    // Get the service instance through binder
                    val binder = service as? AudioPlayerService.LocalBinder
                    val audioService = binder?.service
                    
                    if (audioService != null) {
                        // Check if service is fully initialized
                        audioService.checkReadiness { isReady ->
                            callback(Result.success(isReady))
                            // Unbind after checking
                            unbindService(this)
                        }
                    } else {
                        // Service connected but binder is wrong type
                        callback(Result.success(false))
                        unbindService(this)
                    }
                } catch (e: Exception) {
                    // Error during service connection
                    println("❌ Error checking service readiness: ${e.message}")
                    callback(Result.success(false))
                    try {
                        unbindService(this)
                    } catch (e: Exception) {
                        // Ignore unbinding errors
                    }
                }
            }

            override fun onServiceDisconnected(name: android.content.ComponentName?) {
                // Service crashed or was killed
                callback(Result.success(false))
            }
        }
        
        try {
            // Try to bind to the service
            val bound = bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
            if (!bound) {
                // Could not bind to service
                callback(Result.success(false))
            }
        } catch (e: Exception) {
            // Error binding to service
            println("❌ Error binding to service: ${e.message}")
            callback(Result.success(false))
        }
    }

    private fun checkAndSendCompletionData() {
        activityScope.launch(Dispatchers.IO) {
            val completionData = SharedPreferencesManager.getCompletionData(this@MainActivity)
            if (completionData != null) {
                try {
                    withContext(Dispatchers.Main) {
                        meditoAudioApi?.handleCompletedTrack(completionData) {
                            if (it.isSuccess) {
                                activityScope.launch(Dispatchers.IO) {
                                    SharedPreferencesManager.clearCompletionData(this@MainActivity)
                                }
                            }
                        }
                    }
                } catch (e: Exception) {
                    println("Error parsing completion data: ${e.message}")
                }
            }
        }
    }

    companion object {
        const val ENGINE_ID = "medito_flutter_engine"
        const val REMINDER_CHANNEL_ID = "medito_reminder_channel"
        const val NEWS_CHANNEL_ID = "medito_news_channel"
        const val FIREBASE_CHANNEL_ID = "high_importance_channel"
    }
}