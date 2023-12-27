package meditofoundation.medito

import android.content.ComponentName
import android.content.Intent
import android.util.Log
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.MoreExecutors
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {

    private var mediaController: MediaController? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            Log.d("MainActivity", "Method call: ${call.method}")
            when (call.method) {
                PLAY_URL -> {
                    playUrl(call.argument<String>(URL), result)
                }

                PAUSE_AUDIO -> {
                    pauseAudio(result)
                }

                DISPOSE -> {
                    dispose(result)
                }

                else -> {
                    Log.d("MainActivity", "Unknown method call")
                    result.notImplemented()
                }
            }
        }
    }

    private fun dispose(result: MethodChannel.Result) {
        val intent = Intent(this, AudioPlayerService::class.java)
        stopService(intent)
        result.success(null)
    }

    private fun pauseAudio(result: MethodChannel.Result) {
        val intent = Intent(this, AudioPlayerService::class.java).apply {
            putExtra(PAUSE_AUDIO, "")
        }
        startForegroundService(intent)
        result.success(null)
    }

    private fun playUrl(
        url: String?,
        result: MethodChannel.Result
    ) {
        url?.let {
            val intent = Intent(this, AudioPlayerService::class.java).apply {
                putExtra(PLAY_URL, "")
                putExtra(URL, it)
            }
            startService(intent)
        }
        result.success(null)
    }

    override fun onStart() {
        super.onStart()

        val componentName = ComponentName(this, AudioPlayerService::class.java)
        val sessionToken = SessionToken(this, componentName)
        val mediaControllerFuture = MediaController.Builder(this, sessionToken).buildAsync()

        mediaControllerFuture.addListener({
            try {
                mediaController = mediaControllerFuture.get()
                Log.d("MainActivity", "MediaController initialized")
            } catch (e: Exception) {
                Log.e("MainActivity", "Error initializing MediaController", e)
            }
        }, MoreExecutors.directExecutor())

    }

    companion object {
        const val CHANNEL = "meditofoundation.medito/audioplayer"

        const val PLAY_URL = "playUrl"
        const val URL = "url"

        const val PAUSE_AUDIO = "pauseAudio"
        const val DISPOSE = "dispose"
    }
}
