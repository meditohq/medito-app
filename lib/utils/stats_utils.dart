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

import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/cache.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';

//ignore: prefer-match-file-name
enum UnitType { day, min, tracks }

String getUnits(UnitType type, int _) {
  switch (type) {
    case UnitType.day:
      return 'd';
    case UnitType.min:
      return '';
    case UnitType.tracks:
      return '';
  }
}

Future<String> getCurrentStreak() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt(SharedPreferenceConstants.streakCount) ?? 0;
  var streakList = await getStreakList();

  if (streakList.isNotEmpty) {
    var lastDayInStreak =
        DateTime.fromMillisecondsSinceEpoch(int.parse(streakList.last));

    final now = DateTime.now();

    if (longerThanOneDayAgo(lastDayInStreak, now)) {
      streak = 0;
      await prefs.setInt(SharedPreferenceConstants.streakCount, streak);
    }
  }

  return streak.toString();
}

Future<List<String>> getStreakList() async {
  var prefs = await SharedPreferences.getInstance();

  return prefs.getStringList(SharedPreferenceConstants.streakList) ?? [];
}

Future<bool> setStreakList(List<String> streakList) async {
  var prefs = await SharedPreferences.getInstance();

  return prefs.setStringList(SharedPreferenceConstants.streakList, streakList);
}

Future<int> _getCurrentStreakInt() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt(SharedPreferenceConstants.streakCount);

  return streak ?? 0;
}

Future<bool> updateMinuteCounter(int additionalSecs) async {
  var prefs = await SharedPreferences.getInstance();

  var current = await _getSecondsListened();
  var plusOne = current + (additionalSecs);
  await prefs.setInt(SharedPreferenceConstants.secsListened, plusOne);

  return true;
}

Future<void> updateStreak({String streak = ''}) async {
  var prefs = await SharedPreferences.getInstance();

  if (streak.isNotEmpty) {
    await prefs.setInt(
      SharedPreferenceConstants.streakCount,
      int.parse(streak),
    );
    await _updateLongestStreak(int.parse(streak), prefs);
    await addPhantomTrackToStreakList();

    return;
  }

  var streakList = await getStreakList();
  var streakCount = prefs.getInt(SharedPreferenceConstants.streakCount) ?? 0;

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

Future<void> addPhantomTrackToStreakList() async {
  //add this track to the streak list to stop it resetting to 0,
  // but keep a note of it in fakeStreakList

  var prefs = await SharedPreferences.getInstance();
  var streakList = await getStreakList();
  var fakeStreakList =
      prefs.getStringList(SharedPreferenceConstants.fakeStreakList) ?? [];
  var streakTime = DateTime.now().millisecondsSinceEpoch.toString();
  streakList.add(streakTime);
  fakeStreakList.add(streakTime);
  await setStreakList(streakList);
  await prefs.setStringList(
    SharedPreferenceConstants.fakeStreakList,
    fakeStreakList,
  );
}

Future<void> incrementStreakCounter(
  int streakCount,
) async {
  var prefs = await SharedPreferences.getInstance();

  streakCount++;
  await prefs.setInt(SharedPreferenceConstants.streakCount, streakCount);

  //update longestStreak
  await _updateLongestStreak(streakCount, prefs);
}

Future _updateLongestStreak(int streakCount, SharedPreferences prefs) async {
  //update longestStreak
  var longest = await _getLongestStreakInt();
  if (streakCount > longest) {
    await prefs.setInt(SharedPreferenceConstants.longestStreak, streakCount);
  }
}

void setLongestStreakToCurrentStreak() async {
  var prefs = await SharedPreferences.getInstance();
  var current = await _getCurrentStreakInt();
  await prefs.setInt(SharedPreferenceConstants.longestStreak, current);
}

Future<String> getMinutesListened() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt(SharedPreferenceConstants.secsListened);

  return streak == null ? '0' : Duration(seconds: streak).inMinutes.toString();
}

Future<int> _getSecondsListened() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt(SharedPreferenceConstants.secsListened);

  return streak ?? 0;
}

Future<String> getLongestStreak() async {
  var prefs = await SharedPreferences.getInstance();

  if (await _getLongestStreakInt() < await _getCurrentStreakInt()) {
    return getCurrentStreak();
  }

  var streak = prefs.getInt(SharedPreferenceConstants.longestStreak);

  return streak == null ? '0' : streak.toString();
}

Future<int> _getLongestStreakInt() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt(SharedPreferenceConstants.longestStreak);

  return streak ?? 0;
}

Future<String> getNumTracks() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt(SharedPreferenceConstants.numSessions);

  return streak == null ? '0' : streak.toString();
}

Future<int> getNumTracksInt() async {
  var prefs = await SharedPreferences.getInstance();

  var streak = prefs.getInt(SharedPreferenceConstants.numSessions);

  return streak ?? 0;
}

Future<int> incrementNumTracks() async {
  var prefs = await SharedPreferences.getInstance();
  var current = await getNumTracksInt();
  current++;
  await prefs.setInt(SharedPreferenceConstants.numSessions, current);

  return current;
}

void markAsListened(WidgetRef ref, String id) {
  unawaited(ref
      .read(sharedPreferencesProvider)
      .setBool(SharedPreferenceConstants.listened + id, true));
}

Future<void> clearBgStats() {
  return writeJSONToCache('', SharedPreferenceConstants.stats);
}

void setVersionCopySeen(int id) async {
  var prefs = await SharedPreferences.getInstance();
  await prefs.setInt(SharedPreferenceConstants.copy, id);
}

Future<int> getVersionCopyInt() async {
  var prefs = await SharedPreferences.getInstance();

  var version = prefs.getInt(SharedPreferenceConstants.copy);

  return version ?? -1;
}

bool isSameDay(DateTime day1, DateTime day2) {
  return day1.year == day2.year &&
      day1.month == day2.month &&
      day1.day == day2.day;
}

bool longerThanOneDayAgo(DateTime lastDayInStreak, DateTime now) {
  var thirtyTwoHoursAfterTime = DateTime.fromMillisecondsSinceEpoch(
    lastDayInStreak.millisecondsSinceEpoch + 115200000,
  );

  return now.isAfter(thirtyTwoHoursAfterTime);
}

Future updateStatsFromBg(WidgetRef ref) async {
  var read = await readJSONFromCache(SharedPreferenceConstants.stats);

  if (read.isNotNullAndNotEmpty()) {
    var map = decoded(read!);
    var id = map[SharedPreferenceConstants.id];
    var secsListened = map[SharedPreferenceConstants.secsListened];

    if (map != null && map.isNotEmpty) {
      await updateStreak();
      await incrementNumTracks();
      markAsListened(ref, id);
      await updateMinuteCounter(Duration(seconds: secsListened).inSeconds);
    }
    await clearBgStats();
  }
}
