import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/audio/timer_audio_file.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('timer_audio'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('writes a mono 16-bit 8 kHz WAV of exactly the requested length', () async {
    final path = await TimerAudioFile.prepare(
      const Duration(minutes: 20),
      directory: dir,
    );
    final file = File(path);
    const dataBytes = 20 * 60 * 8000 * 2;
    expect(file.lengthSync(), 44 + dataBytes);

    final raf = file.openSync();
    final header = ByteData.sublistView(raf.readSync(44));
    String ascii(int at) =>
        String.fromCharCodes(header.buffer.asUint8List(at, 4));
    expect(ascii(0), 'RIFF');
    expect(header.getUint32(4, Endian.little), 36 + dataBytes);
    expect(ascii(8), 'WAVE');
    expect(header.getUint16(20, Endian.little), 1); // PCM
    expect(header.getUint16(22, Endian.little), 1); // mono
    expect(header.getUint32(24, Endian.little), 8000);
    expect(header.getUint16(34, Endian.little), 16);
    expect(ascii(36), 'data');
    expect(header.getUint32(40, Endian.little), dataBytes);

    // The body is silence: zero samples.
    raf.setPositionSync(44 + dataBytes ~/ 2);
    expect(raf.readSync(1024).every((b) => b == 0), isTrue);
    raf.closeSync();
  });

  test('a stopwatch-length file fits a WAV and reuses an existing file', () async {
    const fiveHours = Duration(hours: 5);
    expect(TimerAudioFile.dataLength(fiveHours), lessThan(0xFFFFFFFF - 36));
    final first = await TimerAudioFile.prepare(fiveHours, directory: dir);
    final modified = File(first).lastModifiedSync();
    final second = await TimerAudioFile.prepare(fiveHours, directory: dir);
    expect(second, first);
    expect(File(second).lastModifiedSync(), modified);
  });

  test('keeps only the newest timer file', () async {
    final old = await TimerAudioFile.prepare(
      const Duration(minutes: 5),
      directory: dir,
    );
    File('${dir.path}/unrelated.wav').writeAsStringSync('keep me');
    final current = await TimerAudioFile.prepare(
      const Duration(minutes: 10),
      directory: dir,
    );
    expect(File(old).existsSync(), isFalse);
    expect(File(current).existsSync(), isTrue);
    expect(File('${dir.path}/unrelated.wav').existsSync(), isTrue);
  });
}
