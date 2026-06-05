package meditofoundation.medito

import meditofoundation.medito.pigeon.*
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
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import android.os.Handler
import android.os.Looper
import android.os.Build
import androidx.activity.enableEdgeToEdge
import androidx.core.content.ContextCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.core.view.WindowInsetsCompat
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.DpSize
import meditofoundation.medito.widget.MeditationWidget
import meditofoundation.medito.widget.MeditationWidgetReceiver
import meditofoundation.medito.widget.ConsistencyWidget
import meditofoundation.medito.widget.ConsistencyWidgetReceiver

@UnstableApi
class MainActivity : FlutterFragmentActivity(), MeditoAndroidAudioServiceManager, MeditoWidgetManager {

    private var meditoAudioApi: MeditoAudioServiceCallbackApi? = null
    private val activityJob = SupervisorJob()
    private val activityScope = CoroutineScope(Dispatchers.Main + activityJob)

    private val healthConnectBridge by lazy { HealthConnectBridge(this, activityScope) }
    private val healthConnectPermissionLauncher = registerForActivityResult(
        androidx.health.connect.client.PermissionController
            .createRequestPermissionResultContract()
    ) { granted ->
        healthConnectBridge.onPermissionResult(granted)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        FlutterEngineCache
            .getInstance()
            .put(ENGINE_ID, flutterEngine)
        super.configureFlutterEngine(flutterEngine)

        MeditoAndroidAudioServiceManager.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        MeditoWidgetManager.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        MeditoAppIconManager.setUp(flutterEngine.dartExecutor.binaryMessenger, AppIconManagerImpl(this))

        healthConnectBridge.attachLauncher(healthConnectPermissionLauncher)
        MeditoHealthConnectManager.setUp(flutterEngine.dartExecutor.binaryMessenger, healthConnectBridge)

        meditoAudioApi = MeditoAudioServiceCallbackApi(flutterEngine.dartExecutor.binaryMessenger)
        checkAndSendCompletionData()
        
        // Set up platform channel for widget updates
        val widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "medito.app/widget")
        widgetChannel.setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                // Run widget update asynchronously to avoid blocking the main thread
                // Note: sendBroadcast should not block, but running on IO thread as defensive measure
                activityScope.launch(Dispatchers.IO) {
                    try {
                        println("🔔 [Widget] Sending widget update broadcast on thread: ${Thread.currentThread().name}")
                        val intent = Intent("es.antonborri.home_widget.UPDATE_WIDGET")
                        intent.setPackage(packageName)
                        sendBroadcast(intent)
                        println("🔔 [Widget] Broadcast sent successfully")
                        withContext(Dispatchers.Main) {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        println("❌ [Widget] Error sending broadcast: ${e.message}")
                        withContext(Dispatchers.Main) {
                            result.error("UPDATE_FAILED", "Failed to send widget update broadcast", e.message)
                        }
                    }
                }
            } else if (call.method == "pinWidget") {
                // pinWidget is already handled by the MeditoWidgetManager interface
                result.notImplemented()
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        
        val windowInsetsController = WindowCompat.getInsetsController(window, window.decorView)
        windowInsetsController?.let { controller ->
            controller.isAppearanceLightStatusBars = false
            controller.isAppearanceLightNavigationBars = false
        }
        
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
        
        try {
            // Use the appropriate method based on Android version
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(this, intent)
            } else {
                startService(intent)
            }
            // Log successful service start attempt
            println("🔊 Service start requested")
        } catch (e: Exception) {
            println("❌ Error starting service: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun isServiceReady(callback: (Result<Boolean>) -> Unit) {
        println("🔊 [Native] isServiceReady called")
        val intent = Intent(this, AudioPlayerService::class.java)
        intent.action = AudioPlayerService.ACTION_BIND_SERVICE
        
        // Add a timeout handler
        val timeoutHandler = Handler(Looper.getMainLooper())
        val timeoutRunnable = Runnable {
            println("❌ [Native] Service binding timeout occurred")
            try {
                callback(Result.success(false))
            } catch (e: Exception) {
                println("❌ [Native] Error handling timeout: ${e.message}")
            }
        }
        // Set a 5-second timeout
        timeoutHandler.postDelayed(timeoutRunnable, 5000)
        
        val serviceConnection = object : android.content.ServiceConnection {
            override fun onServiceConnected(name: android.content.ComponentName?, service: android.os.IBinder?) {
                // Cancel the timeout since we connected
                timeoutHandler.removeCallbacks(timeoutRunnable)
                
                println("🔊 [Native] onServiceConnected called")
                try {
                    val binder = service as? AudioPlayerService.LocalBinder
                    val audioService = binder?.service
                    
                    if (audioService != null) {
                        println("🔊 [Native] Service connected, calling audioService.checkReadiness")
                        audioService.checkReadiness { isReady ->
                            println("🔊 [Native] audioService.checkReadiness callback: isReady = $isReady")
                            callback(Result.success(isReady))
                            println("🔊 [Native] Unbinding service after readiness check")
                            try {
                                unbindService(this)
                            } catch (e: Exception) {
                                println("❌ [Native] Error unbinding service: ${e.message}")
                            }
                        }
                    } else {
                        println("❌ [Native] Service connected but binder is null or wrong type")
                        callback(Result.success(false))
                        println("🔊 [Native] Unbinding service due to binder issue")
                        try {
                            unbindService(this)
                        } catch (e: Exception) {
                            println("❌ [Native] Error unbinding service: ${e.message}")
                        }
                    }
                } catch (e: Exception) {
                    println("❌ [Native] Error in onServiceConnected: ${e.message}")
                    callback(Result.success(false))
                    try {
                        println("🔊 [Native] Unbinding service due to error in onServiceConnected")
                        unbindService(this)
                    } catch (e: Exception) {
                        println("❌ [Native] Error unbinding service: ${e.message}")
                    }
                }
            }

            override fun onServiceDisconnected(name: android.content.ComponentName?) {
                // Cancel timeout if disconnected
                timeoutHandler.removeCallbacks(timeoutRunnable)
                
                println("❌ [Native] onServiceDisconnected called")
                callback(Result.success(false))
            }
        }
        
        try {
            println("🔊 [Native] Attempting to bind service...")
            val bound = bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
            if (!bound) {
                // Cancel the timeout since binding failed immediately
                timeoutHandler.removeCallbacks(timeoutRunnable)
                
                println("❌ [Native] bindService returned false")
                callback(Result.success(false))
            }
            else {
                println("🔊 [Native] bindService returned true")
                // Keep timeout handler running as we're waiting for connection
            }
        } catch (e: Exception) {
            // Cancel the timeout since there was an exception
            timeoutHandler.removeCallbacks(timeoutRunnable)
            
            println("❌ [Native] Error binding to service: ${e.message}")
            callback(Result.success(false))
        }
    }

    override fun pinWidget(widgetType: String, callback: (Result<Boolean>) -> Unit) {
        activityScope.launch(Dispatchers.Main) {
            try {
                val manager = GlanceAppWidgetManager(this@MainActivity)
                val receiver = when (widgetType) {
                    "consistency" -> ConsistencyWidgetReceiver::class.java
                    else -> MeditationWidgetReceiver::class.java
                }
                val widget = when (widgetType) {
                    "consistency" -> ConsistencyWidget()
                    else -> MeditationWidget()
                }
                
                val success = manager.requestPinGlanceAppWidget(
                    receiver = receiver,
                    preview = widget,
                    previewSize = DpSize(245.dp, 115.dp)
                )
                callback(Result.success(success))
            } catch (e: Exception) {
                println("Error pinning widget: ${e.message}")
                callback(Result.failure(e))
            }
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
