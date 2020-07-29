package com.google.flutter.plugins.audiofileplayer;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.media.MediaPlayer;
import android.os.Build;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.UUID;

/**
 * Wraps a MediaPlayer for local asset use by AudiofileplayerPlugin.
 *
 * <p>Used for local audio data only; loading occurs synchronously. Loading remote audio should use
 * RemoteManagedMediaPlayer.
 */
class LocalManagedMediaPlayer extends ManagedMediaPlayer {

  /**
   * Private shared constructor.
   *
   * <p>Callers must subsequently set a data source and call {@link MediaPlayer#prepare()}.
   */
  private LocalManagedMediaPlayer(
      String audioId,
      AudiofileplayerPlugin parentAudioPlugin,
      boolean looping,
      boolean playInBackground)
      throws IllegalArgumentException, IOException {
    super(audioId, parentAudioPlugin, looping, playInBackground);
    player.setOnErrorListener(this);
    player.setOnCompletionListener(this);
    player.setOnSeekCompleteListener(this);
  }

  /**
   * Create a LocalManagedMediaPlayer from an AssetFileDescriptor.
   *
   * @throws IOException if underlying MediaPlayer cannot load AssetFileDescriptor.
   */
  public LocalManagedMediaPlayer(
      String audioId,
      AssetFileDescriptor afd,
      AudiofileplayerPlugin parentAudioPlugin,
      boolean looping,
      boolean playInBackground)
      throws IOException {
    this(audioId, parentAudioPlugin, looping, playInBackground);
    player.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength());
    player.prepare();
  }

  /**
   * Create a LocalManagedMediaPlayer from a path string.
   *
   * @throws IOException if underlying MediaPlayer cannot load the path.
   */
  public LocalManagedMediaPlayer(
      String audioId,
      String path,
      AudiofileplayerPlugin parentAudioPlugin,
      boolean looping,
      boolean playInBackground)
      throws IOException {
    this(audioId, parentAudioPlugin, looping, playInBackground);
    player.setDataSource(path);
    player.prepare();
  }

  /**
   * Create a ManagedMediaPlayer from a byte array.
   *
   * <p>Uses {@link android.media.MediaPlayer#setDataSource(android.media.MediaDataSource)} if
   * available. Otherwise falls back to writing the byte[] to disk and reading it back.
   *
   * @throws IllegalArgumentException if BufferMediaDataSource is invalid.
   * @throws IOException if underlying MediaPlayer cannot load BufferMediaDataSource or
   *     FileDescriptor.
   */
  public LocalManagedMediaPlayer(
      String audioId,
      byte[] audioBytes,
      AudiofileplayerPlugin parentAudioPlugin,
      boolean looping,
      boolean playInBackground,
      Context context)
      throws IOException, IllegalArgumentException, IllegalStateException {
    this(audioId, parentAudioPlugin, looping, playInBackground);
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      player.setDataSource(new BufferMediaDataSource(audioBytes));
    } else {
      // On older SDK versions, write the byte[] to disk, then read as FileDescriptor.
      File tempAudioFile =
          File.createTempFile(UUID.randomUUID().toString(), null, context.getCacheDir());
      tempAudioFile.deleteOnExit();
      FileOutputStream fos = new FileOutputStream(tempAudioFile);
      fos.write(audioBytes);
      fos.close();
      FileInputStream fis = new FileInputStream(tempAudioFile);
      player.setDataSource(fis.getFD());
      fis.close();
    }
    player.prepare();
  }
}
