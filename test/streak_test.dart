/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'package:Medito/utils/stats_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('test longerThanOneDayAgo', () {
    var b = longerThanOneDayAgo(DateTime.parse('2020-07-14 11:59:00'),
        DateTime.parse('2020-07-16 00:01:00'));
    expect(b, true);
  });

  test('test less than 32 hours', () {
    var b = longerThanOneDayAgo(DateTime.parse('2020-07-14 07:00:00'),
        DateTime.parse('2020-07-15 14:01:00'));
    expect(b, false);
  });

  test('test more than 32 hours', () {
    var b = longerThanOneDayAgo(DateTime.parse('2020-07-14 07:00:00'),
        DateTime.parse('2020-07-15 15:01:00'));
    expect(b, true);
  });

  test('test not longerThanOneDayAgo', () {
    var b = longerThanOneDayAgo(DateTime.parse('2020-06-26 18:15:00'),
        DateTime.parse('2020-06-26 19:15:00'));
    expect(b, false);
  });

  test('test not longerThanOneDayAgo', () {
    var b = longerThanOneDayAgo(DateTime.parse('2020-06-26 18:15:00'),
        DateTime.parse('2020-06-27 19:15:00'));
    expect(b, false);
  });

  test('test longerThanOneDayAgo', () {
    var b = longerThanOneDayAgo(DateTime.parse('2020-06-26 09:00:00'),
        DateTime.parse('2020-06-27 18:15:00'));
    expect(b, true);
  });

  test('test is same day', () {
    var b = isSameDay(DateTime.parse('2020-06-27 18:15:00'),
        DateTime.parse('2020-06-27 00:15:00'));
    expect(b, true);
  });

  test('test not is same day 2', () {
    var b = isSameDay(DateTime.parse('2020-06-01 18:15:00'),
        DateTime.parse('2021-06-01 11:15:00'));
    expect(b, false);
  });

  test('test not is same day', () {
    var b = isSameDay(DateTime.parse('2020-06-27 18:15:00'),
        DateTime.parse('2021-06-27 00:15:00'));
    expect(b, false);
  });

  test('test increment counter by 1', () async {
    var prefs = await SharedPreferences.getInstance();

    await prefs.setInt('streakCount', 0);

    await incrementStreakCounter(0);

    var future2 = getCurrentStreak();
    expect(future2, completion('1'));
  });

  test('test updateStreak and check longest', () async {
    await updateStreak(streak: '5');

    var future2 = getCurrentStreak();
    expect(future2, completion('5'));

    await updateStreak(streak: '2');

    var future1 = getLongestStreak();
    expect(future1, completion('5'));
  });

  test('test updateStreak logic', () async {
    var thirtyTwoHoursInMillis = 115200000;

    await updateStreak();

    var currentStreak = await getCurrentStreak();
    expect(currentStreak, '1');
    var streakList = await getStreakList();
    expect(true, streakList.length == 1);

    // streak count should not increment for same day sessions
    streakList.add(DateTime.now().millisecondsSinceEpoch.toString());
    await setStreakList(streakList);
    await updateStreak();
    currentStreak = await getCurrentStreak();
    expect(currentStreak, '1');
    // streak count should increment by 1 if the last session was on previous day and less than 32 hours ago
    streakList.add(
        (DateTime.now().millisecondsSinceEpoch - thirtyTwoHoursInMillis + 50000)
            .toString());
    await setStreakList(streakList);
    await updateStreak();
    currentStreak = await getCurrentStreak();
    expect(currentStreak, '2');

    // reset to 0 if app launched after 32 hours
    streakList.add(
        (DateTime.now().millisecondsSinceEpoch - thirtyTwoHoursInMillis)
            .toString());
    await setStreakList(streakList);
    currentStreak = await getCurrentStreak();
    expect(currentStreak, '0');
    await updateStreak();
    currentStreak = await getCurrentStreak();
    expect(currentStreak, '1');
  });

  test('test update min counter', () async {
    var prefs = await SharedPreferences.getInstance();

    await prefs.setInt('secsListened', 0);

    await updateMinuteCounter(120).then((value) {
      var secsListened = prefs.getInt('secsListened');
      expect(secsListened, 120);
    });
  });

  test('test get min counter', () async {
    var prefs = await SharedPreferences.getInstance();

    await prefs.setInt('secsListened', 0);

    await updateMinuteCounter(120);

    var future = getMinutesListened();
    expect(future, completion('2'));

    //add another min
    await updateMinuteCounter(60);

    var future2 = getMinutesListened();
    expect(future2, completion('3'));

    //add another min
    await updateMinuteCounter(66);

    var future3 = getMinutesListened();
    expect(future3, completion('4'));
  });
}
