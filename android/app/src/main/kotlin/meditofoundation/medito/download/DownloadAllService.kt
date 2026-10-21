package meditofoundation.medito.download

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import meditofoundation.medito.pigeon.BatchStatus
import meditofoundation.medito.pigeon.DownloadAllHostApi
import org.json.JSONArray
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

class DownloadAllManager private constructor(private val context: Context) : DownloadAllHostApi {
    companion object {
        fun register(messenger: BinaryMessenger, context: Context) {
            DownloadAllHostApi.setUp(messenger, DownloadAllManager(context.applicationContext))
        }
    }

    override fun startBatch(manifestJsonPath: String) {
        DownloadAllService.start(context, manifestJsonPath)
    }

    override fun stopBatch() {
        DownloadAllService.stop(context)
    }

    override fun getStatus(): BatchStatus {
        return BatchStatus(
            isRunning = DownloadAllService.isRunning,
            completed = DownloadAllService.completedCount.toLong(),
            total = DownloadAllService.totalCount.toLong(),
            failed = DownloadAllService.failedCount.toLong()
        )
    }
}

class DownloadAllService : Service() {

    companion object {
        const val ACTION_START = "meditofoundation.medito.download.ACTION_START"
        const val ACTION_STOP = "meditofoundation.medito.download.ACTION_STOP"
        const val EXTRA_MANIFEST_PATH = "extra_manifest_path"

        private const val CHANNEL_ID = "medito_download_all"
        private const val NOTIFICATION_ID = 4001

        @Volatile
        var isRunning: Boolean = false
            private set

        @Volatile
        var completedCount: Int = 0
            private set

        @Volatile
        var totalCount: Int = 0
            private set

        @Volatile
        var failedCount: Int = 0
            private set

        fun start(context: Context, manifestPath: String) {
            val intent = Intent(context, DownloadAllService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_MANIFEST_PATH, manifestPath)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, DownloadAllService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.IO + serviceJob)
    private var downloadJob: Job? = null
    private val isCancelled = AtomicBoolean(false)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopDownloads()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                val manifestPath = intent.getStringExtra(EXTRA_MANIFEST_PATH)
                if (manifestPath != null) {
                    startForegroundWithNotification()
                    startDownloads(manifestPath)
                } else {
                    stopSelf()
                }
                return START_NOT_STICKY
            }
        }
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Medito Downloads",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows progress for downloading meditations"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun startForegroundWithNotification() {
        val notification = buildNotification(0, 0, "Preparing downloads...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(completed: Int, total: Int, text: String? = null): Notification {
        val stopIntent = Intent(this, DownloadAllService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val displayText = text ?: "Downloading $completed of $total"

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Medito")
            .setContentText(displayText)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPendingIntent)

        if (total > 0) {
            builder.setProgress(total, completed, false)
        } else {
            builder.setProgress(0, 0, true)
        }

        return builder.build()
    }

    private fun updateNotification(completed: Int, total: Int) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(completed, total))
    }

    private fun startDownloads(manifestPath: String) {
        isCancelled.set(false)
        isRunning = true
        downloadJob?.cancel()

        downloadJob = serviceScope.launch {
            try {
                val manifestFile = File(manifestPath)
                if (!manifestFile.exists()) {
                    return@launch
                }

                val manifestContent = manifestFile.readText()
                val jsonArray = JSONArray(manifestContent)
                val items = mutableListOf<DownloadItem>()
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    items.add(
                        DownloadItem(
                            url = obj.getString("url"),
                            fileName = obj.getString("fileName")
                        )
                    )
                }

                totalCount = items.size
                completedCount = 0
                failedCount = 0

                val targetDir = applicationContext.filesDir
                val semaphore = Semaphore(4)
                val completedCounter = AtomicInteger(0)
                val failedCounter = AtomicInteger(0)

                val jobs = items.map { item ->
                    launch {
                        semaphore.withPermit {
                            if (isCancelled.get()) return@withPermit

                            val targetFile = File(targetDir, item.fileName)
                            if (targetFile.exists() && targetFile.length() > 0) {
                                val c = completedCounter.incrementAndGet()
                                completedCount = c
                                updateNotification(c, items.size)
                                return@withPermit
                            }

                            val partFile = File(targetDir, "${item.fileName}.part")
                            var success = false
                            try {
                                val url = URL(item.url)
                                val conn = url.openConnection() as HttpURLConnection
                                conn.connectTimeout = 15000
                                conn.readTimeout = 30000
                                conn.instanceFollowRedirects = true

                                if (conn.responseCode in 200..299) {
                                    conn.inputStream.use { input ->
                                        FileOutputStream(partFile).use { output ->
                                            val buffer = ByteArray(8192)
                                            var read: Int
                                            while (input.read(buffer).also { read = it } != -1) {
                                                if (isCancelled.get()) {
                                                    throw CancellationException("Download cancelled")
                                                }
                                                output.write(buffer, 0, read)
                                            }
                                            output.flush()
                                        }
                                    }
                                    if (partFile.exists() && partFile.length() > 0) {
                                        success = partFile.renameTo(targetFile)
                                    }
                                }
                            } catch (e: CancellationException) {
                                if (partFile.exists()) partFile.delete()
                                throw e
                            } catch (e: Exception) {
                                if (partFile.exists()) partFile.delete()
                                failedCounter.incrementAndGet()
                            }

                            if (success) {
                                val c = completedCounter.incrementAndGet()
                                completedCount = c
                                updateNotification(c, items.size)
                            }
                        }
                    }
                }

                jobs.joinAll()
            } catch (e: CancellationException) {
                // Stopped by user
            } catch (e: Exception) {
                // Ignore unexpected errors
            } finally {
                isRunning = false
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
    }

    private fun stopDownloads() {
        isCancelled.set(true)
        downloadJob?.cancel()
        isRunning = false
        try {
            val dir = applicationContext.filesDir
            dir.listFiles { _, name -> name.endsWith(".part") }?.forEach { it.delete() }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        stopDownloads()
        serviceScope.cancel()
        super.onDestroy()
    }

    private data class DownloadItem(
        val url: String,
        val fileName: String
    )
}
