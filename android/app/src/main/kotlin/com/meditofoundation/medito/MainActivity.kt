package meditofoundation.medito

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        FlutterEngineCache
            .getInstance()
            .put(ENGINE_ID, flutterEngine);
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        startAudioService()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        createNotificationChannel()
    }

    override fun onResume() {
        super.onResume()
        startAudioService()
    }

    private fun startAudioService() {
        val intent = Intent(this, AudioPlayerService::class.java)
        startService(intent)
    }

    companion object {
        const val ENGINE_ID = "medito_flutter_engine"
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
}
