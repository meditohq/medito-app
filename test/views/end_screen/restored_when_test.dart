import 'package:flutter_test/flutter_test.dart';
import 'package:medito/views/end_screen/restored_when.dart';

void main() {
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 10, day, hour, minute);

  final cases = <String, (DateTime, DateTime, RestoredWhen)>{
    'sleep story ending before midnight, opened next morning': (
      at(11, 23, 30),
      at(12, 7),
      RestoredWhen.lastNight,
    ),
    'sleep story crossing midnight, opened next morning': (
      at(12, 0, 15),
      at(12, 7),
      RestoredWhen.lastNight,
    ),
    'evening session, opened the next evening': (
      at(11, 20),
      at(12, 19),
      RestoredWhen.lastNight,
    ),
    'late session, opened after midnight': (
      at(11, 23),
      at(12, 1),
      RestoredWhen.lastNight,
    ),
    'small-hours session, opened the same small hours': (
      at(12, 1),
      at(12, 2),
      RestoredWhen.earlierToday,
    ),
    'evening session, opened later that evening': (
      at(12, 19),
      at(12, 22),
      RestoredWhen.earlierToday,
    ),
    'afternoon session, opened that evening': (
      at(12, 14),
      at(12, 18, 30),
      RestoredWhen.earlierToday,
    ),
    'afternoon session, opened next morning': (
      at(11, 14),
      at(12, 10),
      RestoredWhen.yesterday,
    ),
  };

  cases.forEach((name, c) {
    test(name, () => expect(restoredWhen(c.$1, c.$2), c.$3));
  });

  test('today/yesterday follow the day-boundary setting', () {
    // Opened at 03:00 after an afternoon session: with the day starting at
    // 04:00, 03:00 still belongs to the 11th, so that was earlier today.
    expect(restoredWhen(at(11, 15), at(12, 3)), RestoredWhen.yesterday);
    expect(
      restoredWhen(
        at(11, 15),
        at(12, 3),
        dayBoundary: const Duration(hours: 4),
      ),
      RestoredWhen.earlierToday,
    );
  });
}
