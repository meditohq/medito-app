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

import 'package:shared_preferences/shared_preferences.dart';

enum UnitType { day, min }

String getUnits(UnitType type, int value) {
  switch (type) {
    case UnitType.day:
      return value == 1 ? 'day' : 'days';
      break;
    case UnitType.min:
      return value == 1 ? 'min' : 'mins';
      break;
  }
  return '';
}

Future<String> getCurrentStreak() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt('streakCount') ?? 0;
  List<String> streakList = prefs.getStringList('streakList') ?? [];

  if (streakList.length > 0) {
    DateTime lastDayInStreak =
        DateTime.fromMillisecondsSinceEpoch(int.parse(streakList.last));

    final now = DateTime.now();

    if (longerThanOneDayAgo(lastDayInStreak, now)) {
      updateStreak(streak: "0");
      streak = 0;
    }
  }

  return streak.toString();
}

Future<int> _getCurrentStreakInt() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt('streakCount');
  return streak ?? 0;
}

Future<bool> updateMinuteCounter(int additionalSecs) async {
  var prefs = await SharedPreferences.getInstance();

  var current = await _getSecondsListened();
  var plusOne = current + (additionalSecs ?? 0);
  prefs.setInt('secsListened', plusOne);
  return true;
}

void updateStreak({String streak = ''}) async {
  var prefs = await SharedPreferences.getInstance();

  if (streak.isNotEmpty) {
    prefs.setInt('streakCount', int.parse(streak));
    _updateLongestStreak(int.parse(streak), prefs);
    await addPhantomSessionToStreakList();
    return;
  }

  List<String> streakList = prefs.getStringList('streakList') ?? [];
  int streakCount = prefs.getInt('streakCount') ?? 0;

  if (streakList.isNotEmpty) {
    //if you have meditated before, was it on today? if not, increase counter
    final lastDayInStreak =
        DateTime.fromMillisecondsSinceEpoch(int.parse(streakList.last));
    final now = DateTime.now();

    if (!isSameDay(lastDayInStreak, now)) {
      incrementStreakCounter(streakCount);
    }
  } else {
    //if you've never done one before
    incrementStreakCounter(streakCount);
  }

  streakList.add(DateTime.now().millisecondsSinceEpoch.toString());
  prefs.setStringList('streakList', streakList);
}

Future<void> addPhantomSessionToStreakList() async {
  //add this session to the streak list to stop it resetting to 0,
  // but keep a note of it in fakeStreakList

  var prefs = await SharedPreferences.getInstance();
  List<String> streakList = prefs.getStringList('streakList') ?? [];
  List<String> fakeStreakList = prefs.getStringList('fakeStreakList') ?? [];
  var streakTime = DateTime.now().millisecondsSinceEpoch.toString();
  streakList.add(streakTime);
  fakeStreakList.add(streakTime);
  prefs.setStringList('streakList', streakList);
  prefs.setStringList('fakeStreakList', fakeStreakList);
}

Future<void> incrementStreakCounter(
  int streakCount,
) async {
  var prefs = await SharedPreferences.getInstance();

  streakCount++;
  prefs.setInt('streakCount', streakCount);

  //update longestStreak
  await _updateLongestStreak(streakCount, prefs);
}

Future _updateLongestStreak(int streakCount, SharedPreferences prefs) async {
  //update longestStreak
  var longest = await _getLongestStreakInt();
  if (streakCount > longest) {
    prefs.setInt('longestStreak', streakCount);
  }
}

void setLongestStreakToCurrentStreak() async {
  var prefs = await SharedPreferences.getInstance();
  var current = await _getCurrentStreakInt();
  prefs.setInt('longestStreak', current);
}

Future<String> getMinutesListened() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt('secsListened');
  if (streak == null)
    return '0';
  else
    return Duration(seconds: streak).inMinutes.toString();
}

Future<int> _getSecondsListened() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt('secsListened');
  if (streak == null)
    return 0;
  else
    return streak;
}

Future<String> getLongestStreak() async {
  var prefs = await SharedPreferences.getInstance();

  if (await _getLongestStreakInt() < await _getCurrentStreakInt()) {
    return getCurrentStreak();
  }

  var streak = prefs.getInt('longestStreak');
  if (streak == null)
    return '0';
  else
    return streak.toString();
}

Future<int> _getLongestStreakInt() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt('longestStreak');
  return streak ?? 0;
}

Future<String> getNumSessions() async {
  var prefs = await SharedPreferences.getInstance();

  if (prefs == null) return '...';

  var streak = prefs.getInt('numSessions');
  if (streak == null)
    return '0';
  else
    return streak.toString();
}

Future<int> getNumSessionsInt() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt('numSessions');
  return streak ?? 0;
}

Future<int> incrementNumSessions() async {
  var prefs = await SharedPreferences.getInstance();
  var current = await getNumSessionsInt();
  current++;
  prefs.setInt('numSessions', current);
  return current;
}

void markAsListened(String id) async {
  var prefs = await SharedPreferences.getInstance();
  prefs?.setBool('listened' + id, true);
}

bool isSameDay(DateTime day1, DateTime day2) {
  return day1.year == day2.year &&
      day1.month == day2.month &&
      day1.day == day2.day;
}

bool longerThanOneDayAgo(DateTime lastDayInStreak, DateTime now) {
  var oneDayAfterMidnightThatNight = DateTime(lastDayInStreak.year,
      lastDayInStreak.month, lastDayInStreak.day + 1, 23, 59, 59);
  return now.isAfter(oneDayAfterMidnightThatNight);
}
