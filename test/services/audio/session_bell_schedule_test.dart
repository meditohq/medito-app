import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/audio/session_bell_schedule.dart';

void main() {
  const duration = Duration(minutes: 10);
  late SessionBellSchedule cues;
  setUp(() => cues = SessionBellSchedule());

  test('start and midpoint ring only once, based on media position', () {
    expect(cues.update(Duration.zero, duration), isTrue);
    expect(cues.update(Duration.zero, duration), isFalse);
    expect(cues.update(const Duration(minutes: 4), duration), isFalse);
    expect(cues.update(const Duration(minutes: 5), duration), isTrue);
    expect(cues.update(const Duration(minutes: 5), duration), isFalse);
    expect(cues.update(duration, duration), isFalse);
  });

  test('unknown duration does not consume the opening cue', () {
    expect(cues.update(Duration.zero, Duration.zero), isFalse);
    expect(cues.update(Duration.zero, duration), isTrue);
  });

  test('selection late in a session skips elapsed cues', () {
    expect(cues.update(const Duration(minutes: 6), duration), isFalse);
    expect(cues.update(const Duration(minutes: 7), duration), isFalse);
  });

  test('seek forward skips midpoint and rewind rearms it', () {
    cues.update(Duration.zero, duration);
    cues.seek(const Duration(minutes: 6), duration);
    expect(cues.update(const Duration(minutes: 6), duration), isFalse);
    cues.seek(const Duration(minutes: 4), duration);
    expect(cues.update(const Duration(minutes: 4), duration), isFalse);
    expect(cues.update(const Duration(minutes: 5), duration), isTrue);
  });

  test('restart or repeat rearms opening and midpoint', () {
    cues.update(Duration.zero, duration);
    cues.update(const Duration(minutes: 5), duration);
    cues.seek(Duration.zero, duration);
    expect(cues.update(Duration.zero, duration), isTrue);
    expect(cues.update(const Duration(minutes: 5), duration), isTrue);
    cues.reset();
    expect(cues.update(Duration.zero, duration), isTrue);
  });

  test('final bell starts six wall-clock seconds before completion', () {
    cues.update(Duration.zero, duration);
    cues.update(const Duration(minutes: 5), duration);
    expect(cues.update(const Duration(seconds: 593), duration), isFalse);
    expect(cues.update(const Duration(seconds: 594), duration), isTrue);
    expect(cues.update(const Duration(seconds: 595), duration), isFalse);
    expect(cues.update(duration, duration), isFalse);
  });

  test('final cue allows six seconds at double and half speed', () {
    for (final speed in [.5, 2.0]) {
      cues.reset();
      cues.update(Duration.zero, duration, speed: speed);
      cues.update(const Duration(minutes: 5), duration, speed: speed);
      final cue = duration - Duration(milliseconds: (6000 * speed).round());
      expect(
        cues.update(
          cue - const Duration(milliseconds: 1),
          duration,
          speed: speed,
        ),
        isFalse,
      );
      expect(cues.update(cue, duration, speed: speed), isTrue);
    }
  });

  test('seeking past final cue skips it; rewinding rearms it', () {
    cues.seek(const Duration(seconds: 598), duration);
    expect(cues.update(const Duration(seconds: 598), duration), isFalse);
    cues.seek(const Duration(seconds: 590), duration);
    expect(cues.update(const Duration(seconds: 594), duration), isTrue);
  });

  test('very short sessions merge middle and final cues', () {
    const short = Duration(seconds: 10);
    expect(cues.update(Duration.zero, short), isTrue);
    expect(cues.update(const Duration(seconds: 5), short), isTrue);
    expect(cues.update(const Duration(seconds: 6), short), isFalse);
    expect(cues.update(short, short), isFalse);
  });
}
