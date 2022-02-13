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

import 'package:Medito/main.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/network/cache.dart';
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UnitType { day, min, sessions }

String getUnits(UnitType type, int value) {
  switch (type) {
    case UnitType.day:
      return 'd';
      break;
    case UnitType.min:
      return '';
      break;
    case UnitType.sessions:
      return '';
      break;
  }
  return '';
}

Future<String> getCurrentStreak() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt('streakCount') ?? 0;
  var streakList = await getStreakList();

  if (streakList.isNotEmpty) {
    var lastDayInStreak =
        DateTime.fromMillisecondsSinceEpoch(int.parse(streakList.last));

    final now = DateTime.now();

    if (longerThanOneDayAgo(lastDayInStreak, now)) {
      streak = 0;
      await prefs.setInt('streakCount', streak);
    }
  }

  return streak.toString();
}

Future<List<String>> getStreakList() async {
  var prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('streakList') ?? [];
}

Future<void> setStreakList(List<String> streakList) async {
  var prefs = await SharedPreferences.getInstance();
  return prefs.setStringList('streakList', streakList);
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
  await prefs.setInt('secsListened', plusOne);
  return true;
}

Future<void> updateStreak({String streak = ''}) async {
  print('update streak');

  var prefs = await SharedPreferences.getInstance();

  if (streak.isNotEmpty) {
    await prefs.setInt('streakCount', int.parse(streak));
    await _updateLongestStreak(int.parse(streak), prefs);
    await addPhantomSessionToStreakList();
    return;
  }

  var streakList = await getStreakList();
  var streakCount = prefs.getInt('streakCount') ?? 0;

  if (streakList.isNotEmpty) {
    //if you have meditated before, was it on today? if not, increase counter
    final lastDayInStreak =
        DateTime.fromMillisecondsSinceEpoch(int.parse(streakList.last));
    final now = DateTime.now();

    if (!isSameDay(lastDayInStreak, now)) {
      await incrementStreakCounter(streakCount);
    }
  } else {
    //if you've never done one before
    await incrementStreakCounter(streakCount);
  }

  streakList.add(DateTime.now().millisecondsSinceEpoch.toString());
  await setStreakList(streakList);
}

Future<void> addPhantomSessionToStreakList() async {
  //add this session to the streak list to stop it resetting to 0,
  // but keep a note of it in fakeStreakList

  var prefs = await SharedPreferences.getInstance();
  var streakList = await getStreakList();
  var fakeStreakList = prefs.getStringList('fakeStreakList') ?? [];
  var streakTime = DateTime.now().millisecondsSinceEpoch.toString();
  streakList.add(streakTime);
  fakeStreakList.add(streakTime);
  await setStreakList(streakList);
  await prefs.setStringList('fakeStreakList', fakeStreakList);
}

Future<void> incrementStreakCounter(
  int streakCount,
) async {
  var prefs = await SharedPreferences.getInstance();

  streakCount++;
  await prefs.setInt('streakCount', streakCount);

  //update longestStreak
  await _updateLongestStreak(streakCount, prefs);
}

Future _updateLongestStreak(int streakCount, SharedPreferences prefs) async {
  //update longestStreak
  var longest = await _getLongestStreakInt();
  if (streakCount > longest) {
    await prefs.setInt('longestStreak', streakCount);
  }
}

void setLongestStreakToCurrentStreak() async {
  var prefs = await SharedPreferences.getInstance();
  var current = await _getCurrentStreakInt();
  await prefs.setInt('longestStreak', current);
}

Future<String> getMinutesListened() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt('secsListened');
  if (streak == null) {
    return '0';
  } else {
    return Duration(seconds: streak).inMinutes.toString();
  }
}

Future<int> _getSecondsListened() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt('secsListened');
  if (streak == null) {
    return 0;
  } else {
    return streak;
  }
}

Future<String> getLongestStreak() async {
  var prefs = await SharedPreferences.getInstance();

  if (await _getLongestStreakInt() < await _getCurrentStreakInt()) {
    return getCurrentStreak();
  }

  var streak = prefs.getInt('longestStreak');
  if (streak == null) {
    return '0';
  } else {
    return streak.toString();
  }
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
  if (streak == null) {
    return '0';
  } else {
    return streak.toString();
  }
}

Future<int> getNumSessionsInt() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt('numSessions');
  return streak ?? 0;
}

Future<int> incrementNumSessions() async {
  print('increase number of sessions');
  var prefs = await SharedPreferences.getInstance();
  var current = await getNumSessionsInt();
  current++;
  await prefs.setInt('numSessions', current);
  return current;
}

void toggleListenedStatus(String id, String oldId) {
  var listened = checkListened(id, oldId: oldId);
  if (listened) {
    markAsNotListened(id, oldId);
  } else {
    markAsListened(id);
  }
}

void markAsListened(String id) {
  print('mark as listened');
  unawaited(sharedPreferences.setBool('listened' + id, true));
}

void markAsNotListened(String id, String oldId) {
  sharedPreferences.setBool('listened' + id, false);
  if (oldId != null) {
    sharedPreferences.setBool('listened' + oldId, false);
  }
}

Future<void> clearBgStats() {
  return writeJSONToCache('', 'stats');
}

bool checkListened(String id, {String oldId}) {
  var listened = sharedPreferences.getBool('listened' + id) ?? false;

  if (!listened && oldId.isNotEmptyAndNotNull()) {
    return sharedPreferences.getBool('listened' + oldId) ?? false;
  } else {
    return listened;
  }
}

void setVersionCopySeen(int id) async {
  var prefs = await SharedPreferences.getInstance();
  await prefs?.setInt('copy', id);
}

Future<int> getVersionCopyInt() async {
  var prefs = await SharedPreferences.getInstance();

  var version = prefs.getInt('copy');
  return version ?? -1;
}

bool isSameDay(DateTime day1, DateTime day2) {
  return day1.year == day2.year &&
      day1.month == day2.month &&
      day1.day == day2.day;
}

bool longerThanOneDayAgo(DateTime lastDayInStreak, DateTime now) {
  var thirtyTwoHoursAfterTime = DateTime.fromMillisecondsSinceEpoch(
      lastDayInStreak.millisecondsSinceEpoch + 115200000);
  return now.isAfter(thirtyTwoHoursAfterTime);
}

Future updateStatsFromBg() async {
  var read = await readJSONFromCache('stats');
  print('read ->$read');

  if (read.isNotEmptyAndNotNull()) {
    var map = decoded(read);
    var id = map['id'];
    var secsListened = map['secsListened'];

    if (map != null && map.isNotEmpty) {
      await updateStreak();
      await incrementNumSessions();
      await markAsListened(id);
      await updateMinuteCounter(Duration(seconds: secsListened).inSeconds);
    }
    print('clearing bg stats');
    await clearBgStats();
  }
}
