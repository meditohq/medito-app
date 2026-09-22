@file:androidx.media3.common.util.UnstableApi
package meditofoundation.medito

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer

/** Native scheduling continues with the screen locked, without a Dart timer. */
internal class SessionBellPlayer(context: Context, private val primary: Player) : Player.Listener {
    companion object { const val URI = "medito://session-bells" }
    private val handler = Handler(Looper.getMainLooper())
    private val schedule = SessionBellSchedule()
    private val bell = ExoPlayer.Builder(context).build().apply {
        setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).build(), false)
        setHandleAudioBecomingNoisy(true)
        setWakeMode(C.WAKE_MODE_LOCAL)
        addListener(object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                Log.e("BELLS", "Bell playback failed", error)
            }
        })
    }
    private var enabled = false
    private val tick = object : Runnable {
        override fun run() {
            update()
            if (enabled) handler.postDelayed(this, 100)
        }
    }

    init { primary.addListener(this) }

    fun enable(volume: Float) {
        if (enabled) return
        disable()
        enabled = true
        schedule.reset()
        bell.volume = volume
        bell.setMediaItem(MediaItem.fromUri("asset:///flutter_assets/assets/audio/session_bell_v2.wav"))
        bell.prepare()
        handler.post(tick)
    }

    fun setVolume(volume: Float) { bell.volume = volume }

    fun disable() {
        enabled = false
        handler.removeCallbacks(tick)
        bell.stop()
    }

    fun reset() {
        schedule.reset()
        bell.pause()
    }

    private fun ring() {
        bell.seekTo(0)
        if (bell.playbackState == Player.STATE_IDLE) bell.prepare()
        bell.play()
    }

    private fun update() {
        if (!enabled) return
        if (primary.playbackState == Player.STATE_ENDED) {
            bell.pause()
            return
        }
        if (!primary.isPlaying) { bell.pause(); return }
        if (schedule.update(primary.currentPosition, primary.duration, primary.playbackParameters.speed.toDouble())) ring()
        else if (bell.playbackState == Player.STATE_READY && bell.currentPosition > 0) bell.play()
    }

    override fun onEvents(player: Player, events: Player.Events) { update() }

    override fun onPositionDiscontinuity(old: Player.PositionInfo, new: Player.PositionInfo, reason: Int) {
        if (reason == Player.DISCONTINUITY_REASON_AUTO_TRANSITION) schedule.reset()
        else if (reason == Player.DISCONTINUITY_REASON_SEEK) {
            bell.pause()
            schedule.seek(new.positionMs, primary.duration, primary.playbackParameters.speed.toDouble())
        }
        update()
    }

    fun release() {
        disable()
        primary.removeListener(this)
        bell.release()
    }
}
