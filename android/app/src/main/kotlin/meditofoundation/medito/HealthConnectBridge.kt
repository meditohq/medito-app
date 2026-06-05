package meditofoundation.medito

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContract
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.MindfulnessSessionRecord
import androidx.health.connect.client.records.metadata.Metadata
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import meditofoundation.medito.pigeon.HealthConnectStatus
import meditofoundation.medito.pigeon.MeditoHealthConnectManager
import java.time.Instant
import java.time.ZoneOffset

class HealthConnectBridge(
    private val context: Context,
    private val scope: CoroutineScope,
) : MeditoHealthConnectManager {

    private val permissions = setOf(
        HealthPermission.getReadPermission(MindfulnessSessionRecord::class),
        HealthPermission.getWritePermission(MindfulnessSessionRecord::class),
    )

    private var permissionLauncher: ActivityResultLauncher<Set<String>>? = null
    private var pendingPermissionResult: CompletableDeferred<Set<String>>? = null

    fun permissionContract(): ActivityResultContract<Set<String>, Set<String>> =
        PermissionController.createRequestPermissionResultContract()

    fun attachLauncher(launcher: ActivityResultLauncher<Set<String>>) {
        permissionLauncher = launcher
    }

    fun onPermissionResult(granted: Set<String>) {
        pendingPermissionResult?.complete(granted)
        pendingPermissionResult = null
    }

    private fun clientOrNull(): HealthConnectClient? {
        return when (HealthConnectClient.getSdkStatus(context)) {
            HealthConnectClient.SDK_AVAILABLE -> HealthConnectClient.getOrCreate(context)
            else -> null
        }
    }

    override fun getStatus(callback: (Result<HealthConnectStatus>) -> Unit) {
        val status = when (HealthConnectClient.getSdkStatus(context)) {
            HealthConnectClient.SDK_AVAILABLE -> HealthConnectStatus.AVAILABLE
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED ->
                HealthConnectStatus.NOT_INSTALLED
            else -> HealthConnectStatus.NOT_SUPPORTED
        }
        callback(Result.success(status))
    }

    override fun hasMindfulnessPermissions(callback: (Result<Boolean>) -> Unit) {
        val client = clientOrNull() ?: return callback(Result.success(false))
        scope.launch(Dispatchers.IO) {
            try {
                val granted = client.permissionController.getGrantedPermissions()
                callback(Result.success(granted.containsAll(permissions)))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    override fun requestMindfulnessPermissions(callback: (Result<Boolean>) -> Unit) {
        val client = clientOrNull() ?: return callback(Result.success(false))
        val launcher = permissionLauncher ?: return callback(Result.success(false))

        scope.launch(Dispatchers.Main) {
            try {
                val already = client.permissionController.getGrantedPermissions()
                if (already.containsAll(permissions)) {
                    callback(Result.success(true))
                    return@launch
                }

                val deferred = CompletableDeferred<Set<String>>()
                pendingPermissionResult = deferred
                launcher.launch(permissions)
                val granted = deferred.await()
                callback(Result.success(granted.containsAll(permissions)))
            } catch (e: Exception) {
                pendingPermissionResult = null
                callback(Result.failure(e))
            }
        }
    }

    override fun writeMindfulnessSession(
        startEpochMs: Long,
        endEpochMs: Long,
        callback: (Result<Boolean>) -> Unit,
    ) {
        val client = clientOrNull() ?: return callback(Result.success(false))
        scope.launch(Dispatchers.IO) {
            try {
                val record = MindfulnessSessionRecord(
                    startTime = Instant.ofEpochMilli(startEpochMs),
                    startZoneOffset = ZoneOffset.UTC,
                    endTime = Instant.ofEpochMilli(endEpochMs),
                    endZoneOffset = ZoneOffset.UTC,
                    mindfulnessSessionType = MindfulnessSessionRecord
                        .MINDFULNESS_SESSION_TYPE_MEDITATION,
                    title = "Medito",
                    notes = null,
                    metadata = Metadata.autoRecorded(
                        device = androidx.health.connect.client.records.metadata
                            .Device(type = androidx.health.connect.client.records.metadata.Device.TYPE_PHONE),
                    ),
                )
                client.insertRecords(listOf(record))
                callback(Result.success(true))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    override fun openHealthConnectInstall() {
        val uri = Uri.parse(
            "market://details?id=com.google.android.apps.healthdata&url=healthconnect%3A%2F%2Fonboarding",
        )
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage("com.android.vending")
            putExtra("overlay", true)
            putExtra("callerId", context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
            val webIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse(
                    "https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata",
                ),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(webIntent)
        }
    }
}
