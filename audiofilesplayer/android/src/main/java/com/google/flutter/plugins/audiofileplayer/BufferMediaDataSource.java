package com.google.flutter.plugins.audiofileplayer;

import android.media.MediaDataSource;
import java.io.IOException;

/** A MediaDataSource implementation to read a byte array of media data. */
final class BufferMediaDataSource extends MediaDataSource {
  private final byte[] bytes;

  public BufferMediaDataSource(byte[] bytes) {
    this.bytes = bytes;
  }

  @Override
  public long getSize() {
    return bytes.length;
  }

  @Override
  public int readAt(long position, byte[] buffer, int offset, int size) {
    if (position >= bytes.length) {
      // Indicate end of stream with -1.
      return -1;
    }
    int readSize = Math.min(size, Math.min(buffer.length - offset, bytes.length - (int) position));
    System.arraycopy(bytes, (int) position, buffer, offset, readSize);
    return readSize;
  }

  @Override
  public void close() throws IOException {}
}
