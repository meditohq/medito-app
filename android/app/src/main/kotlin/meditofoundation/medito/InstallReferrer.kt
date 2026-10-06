package meditofoundation.medito

import android.content.Context
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerClient.InstallReferrerResponse
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Hands Dart the Play Store install referrer (e.g.
 * "utm_source=apps.facebook.com&utm_campaign=fb4a" or "gclid=…") so the
 * install's ad source can be stored like deep-link UTMs. See
 * PlayInstallReferrerService (play_install_referrer_service.dart).
 *
 * Replies with the referrer, "" when this device can never provide one, or an
 * error when it's worth asking again on a later launch.
 */
object InstallReferrer {
    fun register(messenger: BinaryMessenger, context: Context) {
        val appContext = context.applicationContext
        MethodChannel(messenger, "com.medito.app/install_referrer").setMethodCallHandler { call, result ->
            if (call.method != "getReferrer") return@setMethodCallHandler result.notImplemented()
            read(appContext, result)
        }
    }

    private fun read(context: Context, result: MethodChannel.Result) {
        val client = InstallReferrerClient.newBuilder(context).build()
        var replied = false
        fun reply(block: () -> Unit) {
            if (replied) return
            replied = true
            block()
            client.endConnection()
        }

        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    when (responseCode) {
                        InstallReferrerResponse.OK -> reply {
                            try {
                                result.success(client.installReferrer.installReferrer ?: "")
                            } catch (e: Exception) {
                                result.error("read_failed", e.message, null)
                            }
                        }
                        // Not installed from Play (sideload, emulator image
                        // without Play): there will never be a referrer.
                        InstallReferrerResponse.FEATURE_NOT_SUPPORTED -> reply { result.success("") }
                        else -> reply { result.error("unavailable", "Install referrer response $responseCode", null) }
                    }
                }

                override fun onInstallReferrerServiceDisconnected() {
                    reply { result.error("disconnected", "Install referrer service disconnected", null) }
                }
            })
        } catch (e: Exception) {
            reply { result.error("start_failed", e.message, null) }
        }
    }
}
