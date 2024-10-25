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

@UnstableApi
class MainActivity : FlutterFragmentActivity(), MeditoAndroidAudioServiceManager {

    private var meditoAudioApi: MeditoAudioServiceCallbackApi? = null

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

    private fun createNotificationChannels() {
        createAudioServiceNotificationChannel()
        createReminderNotificationChannel()
        createNewsNotificationChannel()
    }

    private fun createAudioServiceNotificationChannel() {
        val channelName = "Meditation audio"
        val importance = NotificationManager.IMPORTANCE_DEFAULT
        val channel = NotificationChannel(AudioPlayerService.CHANNEL_ID, channelName, importance).apply {
            description = "Notification for media control of meditation audio"
        }

        val notificationManager: NotificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
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

    override fun startService() {
        val intent = Intent(this, AudioPlayerService::class.java)
        startForegroundService(intent)
    }

    private fun checkAndSendCompletionData() {
        val completionData = SharedPreferencesManager.getCompletionData(this)
        if (completionData != null) {
            try {
                meditoAudioApi?.handleCompletedTrack(completionData) {
                    // Clear the saved data after sending
                    if (it.isSuccess) {
                        SharedPreferencesManager.clearCompletionData(this)
                    }
                }
            } catch (e: Exception) {
                println("Error parsing completion data: ${e.message}")
            }
        }
    }

    companion object {
        const val ENGINE_ID = "medito_flutter_engine"
        const val REMINDER_CHANNEL_ID = "medito_reminder_channel"
        const val NEWS_CHANNEL_ID = "medito_news_channel"
    }
}