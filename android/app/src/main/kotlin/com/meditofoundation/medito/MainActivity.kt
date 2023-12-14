package meditofoundation.medito

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.util.Log

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d("MainActivity", "Method call: ${call.method}")
            when (call.method) {
                PLAY_URL -> {
                    playUrl(call.argument<String>("url"), result)
                }
                PAUSE_AUDIO -> {
                    pauseAudio(result)
                }
                else -> {
                    Log.d("MainActivity", "Unknown method call")
                    result.notImplemented()
                }
            }
        }
    }

    private fun pauseAudio(result: MethodChannel.Result) {
        val intent = Intent(this, AudioPlayerService::class.java)
        startService(intent)
        result.success(null)
    }

    private fun playUrl(
        url: String?,
        result: MethodChannel.Result
    ) {
        url?.let {
            val intent = Intent(this, AudioPlayerService::class.java).apply {
                putExtra(URL, it)
            }
            startService(intent)
        }
        result.success(null)
    }

    companion object {
        const val CHANNEL = "meditofoundation.medito/audioplayer"
        const val URL = "url"
        const val PLAY_URL = "playUrl"
        const val PAUSE_AUDIO = "pauseAudio"
    }
}
