import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/logger.dart';

/// Writes the silent audio a timer session plays through the regular player.
///
/// A timer has to be real playback, not a Dart countdown: only active audio
/// keeps iOS from suspending the app with the screen locked, and the session
/// bells, background sound fade, lock-screen controls and native completion
/// (which records stats while the app is asleep) all follow the primary
/// player's position. So the timer is a silent track of exactly its length.
///
/// The file is 16-bit PCM, where silence is all zero bytes, so it is written
/// as a header plus a truncate: the body is a sparse hole on APFS, ext4 and
/// f2fs, costing no disk space or write time however long the session.
class TimerAudioFile {
  TimerAudioFile._();

  static const sampleRate = 8000;
  static const _bytesPerSample = 2;
  static const _headerBytes = 44;
  static const _filePrefix = 'medito_timer_';

  /// Returns the path of a silent WAV lasting [duration], creating it in the
  /// temporary directory if needed. Older timer files are removed.
  static Future<String> prepare(
    Duration duration, {
    Directory? directory,
  }) async {
    final dir = directory ?? await getTemporaryDirectory();
    final file = File('${dir.path}/$_filePrefix${duration.inMilliseconds}.wav');
    final dataBytes = dataLength(duration);

    if (!await file.exists() ||
        await file.length() != _headerBytes + dataBytes) {
      final raf = await file.open(mode: FileMode.write);
      try {
        await raf.writeFrom(header(dataBytes));
        await raf.truncate(_headerBytes + dataBytes);
      } finally {
        await raf.close();
      }
    }

    await _deleteOthers(dir, keep: file.path);
    return file.path;
  }

  @visibleForTesting
  static int dataLength(Duration duration) {
    final samples = (duration.inMicroseconds * sampleRate) ~/ 1000000;
    return samples * _bytesPerSample;
  }

  /// Canonical 44-byte RIFF/WAVE header for mono 16-bit PCM.
  @visibleForTesting
  static Uint8List header(int dataBytes) {
    final bytes = ByteData(_headerBytes);
    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little); // fmt chunk size
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * _bytesPerSample, Endian.little);
    bytes.setUint16(32, _bytesPerSample, Endian.little); // block align
    bytes.setUint16(34, 8 * _bytesPerSample, Endian.little);
    ascii(36, 'data');
    bytes.setUint32(40, dataBytes, Endian.little);
    return bytes.buffer.asUint8List();
  }

  static Future<void> _deleteOthers(
    Directory dir, {
    required String keep,
  }) async {
    try {
      await for (final entity in dir.list()) {
        final name = entity.uri.pathSegments.last;
        if (entity is File &&
            entity.path != keep &&
            name.startsWith(_filePrefix)) {
          await entity.delete();
        }
      }
    } catch (e) {
      AppLogger.w('TIMER', 'Could not clear old timer files: $e');
    }
  }
}
