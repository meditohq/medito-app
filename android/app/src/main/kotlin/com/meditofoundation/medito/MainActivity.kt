package meditofoundation.medito

import CompletionData
import MeditoAndroidAudioServiceManager
import MeditoAudioServiceCallbackApi
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import androidx.media3.common.util.UnstableApi
import com.meditofoundation.medito.SharedPreferencesManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugins.GeneratedPluginRegistrant
import org.json.JSONObject


@UnstableApi
class MainActivity : FlutterActivity(), MeditoAndroidAudioServiceManager {

    private lateinit var sharedPreferences: SharedPreferences
    private var meditoAudioApi: MeditoAudioServiceCallbackApi? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        FlutterEngineCache
            .getInstance()
            .put(ENGINE_ID, flutterEngine)
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MeditoAndroidAudioServiceManager.setUp(flutterEngine.dartExecutor.binaryMessenger, this)

        sharedPreferences = getSharedPreferences("AudioCompletion", Context.MODE_PRIVATE)
        meditoAudioApi = MeditoAudioServiceCallbackApi(flutterEngine.dartExecutor.binaryMessenger)
        checkAndSendCompletionData()

    }

    private fun checkAndSendCompletionData() {
        val jsonString = SharedPreferencesManager.getCompletionData(this)
        if (jsonString != null) {
            try {
                val json = JSONObject(jsonString)
                val completionData = CompletionData(
                    trackId = json.getString("trackId"),
                    duration = json.getLong("duration"),
                    fileId = json.getString("fileId"),
                    guideId = json.optString("guideId"),
                    timestamp = json.getLong("timestamp"),
                    userToken = json.optString("userToken")
                )

                meditoAudioApi?.handleCompletedTrack(completionData) {
                    // Clear the saved data after sending
                    SharedPreferencesManager.clearCompletionData(this)
                }
            } catch (e: Exception) {
                println("Error parsing completion data: ${e.message}")
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        createNotificationChannel()
        createReminderNotificationChannel()
    }

    override fun onResume() {
        super.onResume()
        checkAndSendCompletionData()
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
