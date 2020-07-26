package com.google.flutter.plugins.audiofileplayer;

import android.media.MediaPlayer;
import android.util.Log;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**
 * Wraps a MediaPlayer for remote asset use by AudiofileplayerPlugin.
 *
 * <p>Used for remote audio data only; loading occurs asynchronously, allowing program to continue
 * while data is received. Callers may call all other methods on {@link ManagedMediaPlayer}
 * immediately (i.e. before loading is complete); these will, if necessary, be delayed and re-called
 * internally upon loading completion.
 *
 * <p>Note that with async loading, errors such as invalid URLs and lack of connectivity are
 * reported asyncly via {@link RemoteManagedMediaPlayer.onError()}, instead of as Exceptions.
 * Unfortunately, this yields inscrutable and/or undifferentiated error codes, instead of discrete
 * Exception subclasses with human-readable error messages.
 */
class RemoteManagedMediaPlayer extends ManagedMediaPlayer
    implements MediaPlayer.OnPreparedListener {

  interface OnRemoteLoadListener {
    /**
     * Called when asynchronous remote loading has completed, either successfully via {@link
     * RemoteManagedMediaPlayer#onPrepare()}, or unsuccessfully on {@link
     * RemoteManagedMediaPlayer#onError()}.
     */
    void onRemoteLoadComplete(boolean success);
  }

  private static final String TAG = RemoteManagedMediaPlayer.class.getSimpleName();
  private OnRemoteLoadListener onRemoteLoadListener;
  private boolean isPrepared;
  // A list of runnables to run once onPrepared() is called.
  private List<Runnable> onPreparedRunnables = new ArrayList<>();

  /**
   * Create a RemoteManagedMediaPlayer from an remote URL string.
   *
   * <p>Async loading errors (during {@link MediaPlayer#prepareAsync()}) are caught by {@link
   * RemoteManagedMediaPlayer#onError()}, not as Exceptions.
   *
   * @throws IOException if underlying MediaPlayer cannot load it as its DataSource.
   */
  public RemoteManagedMediaPlayer(
      String audioId,
      String remoteUrl,
      AudiofileplayerPlugin parentAudioPlugin,
      boolean looping,
      boolean playInBackground)
      throws IOException {
    super(audioId, parentAudioPlugin, looping, playInBackground);
    player.setDataSource(remoteUrl);
    player.setOnCompletionListener(this);
    player.setOnPreparedListener(this);
    player.setOnErrorListener(this);
    player.setOnSeekCompleteListener(this);
    player.prepareAsync();
  }

  public void setOnRemoteLoadListener(OnRemoteLoadListener onRemoteLoadListener) {
    this.onRemoteLoadListener = onRemoteLoadListener;
  }

  @Override
  public void onPrepared(MediaPlayer mediaPlayer) {
    Log.i(TAG, "on prepared");
    isPrepared = true;
    onRemoteLoadListener.onRemoteLoadComplete(true);
    for (Runnable r : onPreparedRunnables) {
      r.run();
    }
  }

  @Override
  public void play(boolean playFromStart, int endpointMs) {
    if (!isPrepared) {
      onPreparedRunnables.add(() -> RemoteManagedMediaPlayer.super.play(playFromStart, endpointMs));
    } else {
      super.play(playFromStart, endpointMs);
    }
  }

  @Override
  public void release() {
    if (!isPrepared) {
      onPreparedRunnables.add(() -> RemoteManagedMediaPlayer.super.release());
    } else {
      super.release();
    }
  }

  @Override
  public void seek(double positionSeconds) {
    if (!isPrepared) {
      onPreparedRunnables.add(() -> RemoteManagedMediaPlayer.super.seek(positionSeconds));
    } else {
      super.seek(positionSeconds);
    }
  }

  @Override
  public void pause() {
    if (!isPrepared) {
      onPreparedRunnables.add(() -> RemoteManagedMediaPlayer.super.pause());
    } else {
      super.pause();
    }
  }

  @Override
  public boolean onError(MediaPlayer mp, int what, int extra) {
    onRemoteLoadListener.onRemoteLoadComplete(false);
    return super.onError(mp, what, extra);
  }
}
