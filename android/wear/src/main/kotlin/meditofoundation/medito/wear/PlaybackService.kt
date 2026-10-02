package meditofoundation.medito.wear

import android.os.Bundle
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * Streams one session on the watch, through Bluetooth headphones or the
 * watch's own speaker (Pixel Watch and others have one for media).
 */
class PlaybackService : MediaSessionService() {
    private var session: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        // Same HTTP setup as the phone's AudioPlayerService: some session
        // URLs redirect across http/https, which ExoPlayer refuses by default.
        val http = DefaultHttpDataSource.Factory()
            .setUserAgent("Medito-WearOS")
            .setConnectTimeoutMs(15_000)
            .setReadTimeoutMs(30_000)
            .setAllowCrossProtocolRedirects(true)
        val player = ExoPlayer.Builder(this)
            .setMediaSourceFactory(
                DefaultMediaSourceFactory(this)
                    .setDataSourceFactory(DefaultDataSource.Factory(this, http))
            )
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_SPEECH)
                    .build(),
                /* handleAudioFocus = */ true,
            )
            .setHandleAudioBecomingNoisy(true)
            .build()

        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_ENDED) reportCompleted(player.currentMediaItem)
            }
        })

        session = MediaSession.Builder(this, player)
            .setCallback(object : MediaSession.Callback {
                // A MediaController strips the playable URI when it sends a
                // MediaItem; rebuild it from the request metadata.
                override fun onAddMediaItems(
                    mediaSession: MediaSession,
                    controller: MediaSession.ControllerInfo,
                    mediaItems: MutableList<MediaItem>,
                ): ListenableFuture<MutableList<MediaItem>> = Futures.immediateFuture(
                    mediaItems.map { it.buildUpon().setUri(it.requestMetadata.mediaUri).build() }
                        .toMutableList()
                )
            })
            .build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

    override fun onDestroy() {
        session?.run {
            player.release()
            release()
        }
        session = null
        super.onDestroy()
    }

    private fun reportCompleted(item: MediaItem?) {
        item ?: return
        val extras = item.mediaMetadata.extras ?: Bundle.EMPTY
        WatchRepository.reportCompleted(
            trackId = item.mediaId,
            fileId = extras.getString(EXTRA_FILE_ID).orEmpty(),
            guide = extras.getString(EXTRA_GUIDE).orEmpty(),
            durationMs = extras.getLong(EXTRA_DURATION_MS),
        )
    }

    companion object {
        const val EXTRA_FILE_ID = "fileId"
        const val EXTRA_GUIDE = "guide"
        const val EXTRA_DURATION_MS = "durationMs"

        fun mediaItem(track: WatchTrack): MediaItem = MediaItem.Builder()
            .setMediaId(track.id)
            .setRequestMetadata(
                MediaItem.RequestMetadata.Builder()
                    .setMediaUri(WatchDownloads.localUri(track) ?: android.net.Uri.parse(track.audioUrl))
                    .build()
            )
            .setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle(track.title)
                    .setArtist(track.guide)
                    .setExtras(
                        Bundle().apply {
                            putString(EXTRA_FILE_ID, track.fileId)
                            putString(EXTRA_GUIDE, track.guide)
                            putLong(EXTRA_DURATION_MS, track.durationMs)
                        }
                    )
                    .build()
            )
            .build()
    }
}
