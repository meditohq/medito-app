package meditofoundation.medito.pigeon

import android.content.Context
import android.util.Log
import com.tiktok.TikTokBusinessSdk
import org.json.JSONObject

class TikTokPigeonImpl(private val context: Context) : TikTokAndroidApi {
    private var isInitialized = false
    private var testEventCode: String? = null
    
    override fun initialize(appId: String, tiktokAppId: String?, debugMode: Boolean, testEventCode: String?) {
        // Prevent double initialization
        if (isInitialized) {
            Log.d("TikTokPigeon", "SDK already initialized, skipping")
            return
        }
        
        try {
            this.testEventCode = testEventCode
            Log.d("TikTokPigeon", "Received initialize call - appId: '$appId' (length: ${appId.length}), tiktokAppId: '$tiktokAppId', debugMode: $debugMode, testEventCode: '$testEventCode'")
            
            // Check what's in the manifest metadata (for debugging)
            try {
                val appInfo = context.packageManager.getApplicationInfo(context.packageName, android.content.pm.PackageManager.GET_META_DATA)
                val manifestAppId = appInfo.metaData?.getString("com.tiktok.tiktok_business_sdk.property.AppId")
                Log.d("TikTokPigeon", "Manifest metadata AppId: '$manifestAppId'")
            } catch (e: Exception) {
                Log.d("TikTokPigeon", "Could not read manifest metadata: ${e.message}")
            }
            
            // TikTok SDK expects:
            // - appId: Android package name (e.g., "com.example.app") - validated with package name regex
            // - TTAppId: TikTok App ID (numeric, e.g., "7483746287720890385")
            // The numeric ID passed as appId is actually the TikTok App ID, so use it for TTAppId
            // Use the actual Android package name for appId
            val packageName = context.packageName
            val finalAppId = packageName // Use package name for appId
            val finalTTAppId = tiktokAppId ?: appId // Use the numeric TikTok App ID for TTAppId
            
            Log.d("TikTokPigeon", "Using finalAppId (package): '$finalAppId', finalTTAppId (TikTok ID): '$finalTTAppId'")
            
            val config = TikTokBusinessSdk.TTConfig(context)
                .setAppId(finalAppId)
                .setTTAppId(finalTTAppId)
                //.setDebugMode(debugMode)
                .setLogLevel(if (debugMode) TikTokBusinessSdk.LogLevel.DEBUG else TikTokBusinessSdk.LogLevel.INFO)
                //.setAutoIapTrackEnabled(false)

            Log.d("TikTokPigeon", "Calling TikTokBusinessSdk.initializeSdk with appId: '$finalAppId', ttAppId: '$finalTTAppId'")
            TikTokBusinessSdk.initializeSdk(config)
            isInitialized = true
            Log.d("TikTokPigeon", "TikTok SDK initialized natively via Pigeon")
            Log.d("TikTokPigeon", "Note: SDK will fetch config asynchronously. Events will be queued until config fetch succeeds.")
            Log.d("TikTokPigeon", "If network is unavailable, config fetch will fail but SDK will retry automatically when connectivity is restored.")
        } catch (e: Exception) {
            Log.e("TikTokPigeon", "Error initializing TikTok SDK", e)
            // Don't set isInitialized = true on error, so we can retry if needed
            throw e // Re-throw to let Flutter side handle it
        }
    }

    override fun logEvent(eventName: String, properties: Map<String?, Any?>?) {
        try {
            Log.d("TikTokPigeon", "Logging event: $eventName with properties: $properties")
            
            val jsonProps = JSONObject()
            properties?.forEach { (key, value) ->
                if (key != null && value != null) {
                    jsonProps.put(key, value)
                }
            }
            
            // Add test event code if available (for Test Events tab in TikTok console)
            testEventCode?.let { code ->
                jsonProps.put("test_event_code", code)
                Log.d("TikTokPigeon", "Added test event code: $code to event: $eventName")
            }
            
            // Use TikTokBusinessSdk.trackEvent() - the correct API for SDK 1.5.0
            // This is a static method that internally uses TTAppEventLogger
            // Explicitly cast null to JSONObject? to avoid overload resolution ambiguity
            val propsToUse: JSONObject? = if (jsonProps.length() > 0) jsonProps else null
            TikTokBusinessSdk.trackEvent(eventName, propsToUse)
            Log.d("TikTokPigeon", "Successfully logged event: $eventName")
        } catch (e: Exception) {
            Log.e("TikTokPigeon", "Error logging event: $eventName", e)
        }
    }
}

