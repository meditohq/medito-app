package meditofoundation.medito

import MeditoAndroidAudioServiceManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.media3.common.util.UnstableApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugins.GeneratedPluginRegistrant

@UnstableApi
class MainActivity : FlutterActivity(), MeditoAndroidAudioServiceManager {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        FlutterEngineCache
            .getInstance()
            .put(ENGINE_ID, flutterEngine)
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MeditoAndroidAudioServiceManager.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        createNotificationChannel()
        createReminderNotificationChannel()
    }

    private fun createNotificationChannel() {
        val channelName = "Meditation audio"
        val importance = NotificationManager.IMPORTANCE_DEFAULT
        val channel =
            NotificationChannel(AudioPlayerService.CHANNEL_ID, channelName, importance).apply {
                description = "Notification for media control of meditation audio"
            }

        val notificationManager: NotificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }

    private fun createReminderNotificationChannel() {
        val channelName = "Reminders"
        val importance = NotificationManager.IMPORTANCE_HIGH
        val channel =
            NotificationChannel(REMINDER_CHANNEL_ID, channelName, importance).apply {
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

    companion object {
        const val ENGINE_ID = "medito_flutter_engine"
        const val REMINDER_CHANNEL_ID = "medito_reminder_channel"
    }
}
