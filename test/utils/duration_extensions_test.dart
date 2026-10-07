import 'package:flutter_test/flutter_test.dart';
import 'package:medito/utils/duration_extensions.dart';

void main() {
  test('under an hour stays mm:ss', () {
    expect(const Duration(minutes: 5, seconds: 35).toMinutesSeconds(), '05:35');
    expect(
      const Duration(minutes: 59, seconds: 59).toMinutesSeconds(),
      '59:59',
    );
  });

  test('an hour and over shows hours instead of wrapping minutes', () {
    expect(const Duration(hours: 4, minutes: 28).toMinutesSeconds(), '4:28:00');
    expect(const Duration(hours: 3, minutes: 28).toMinutesSeconds(), '3:28:00');
    expect(
      const Duration(hours: 1, minutes: 5, seconds: 9).toMinutesSeconds(),
      '1:05:09',
    );
  });

  test('toReadable no longer wraps at 100 minutes', () {
    expect(
      const Duration(minutes: 120, seconds: 5).toReadable(),
      '120 min 05 sec',
    );
  });
}
