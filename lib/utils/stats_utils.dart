import 'package:shared_preferences/shared_preferences.dart';

Future<String> getCurrentStreak(SharedPreferences prefs) async {
  var streak = prefs.getInt('streakCount');
  if (streak == null)
    return '0';
  else
    return streak.toString();
}

Future<int> _getCurrentStreakInt(SharedPreferences prefs) async {
  var streak = prefs.getInt('streakCount');
  return streak ?? 0;
}

void updateMinuteCounter(SharedPreferences prefs, int additionalSecs) async {
  var current = await _getSecondsListened(prefs);
  var plusOne = current + additionalSecs;
  prefs.setInt('secsListened', plusOne);
}

void updateStreak(SharedPreferences prefs, {String streak = ''}) async {
  assert(prefs != null);

  if (streak.isNotEmpty) {
    prefs.setInt('streakCount', int.parse(streak));
    return;
  }

  List<String> streakList = prefs.getStringList('streakList');
  int streakCount = prefs.getInt('streakCount');

  if (streakList == null) {
    streakList = [];
  }
  if (streakCount == null) {
    streakCount = 0;
  }

  if (streakList.length > 0) {
    //if you have meditated before, was it on today? if not, increase counter
    final lastDayInStreak =
        DateTime.fromMillisecondsSinceEpoch(int.parse(streakList.last));
    final now = DateTime.now();

    if (!isSameDay(lastDayInStreak, now)) {
      incrementStreakCounter(streakCount, prefs);
    }
  } else {
    //if you've never done one before
    incrementStreakCounter(streakCount, prefs);
  }

  streakList.add(DateTime.now().millisecondsSinceEpoch.toString());
  prefs.setStringList('streakList', streakList);
}

Future<void> incrementStreakCounter(
    int streakCount, SharedPreferences prefs) async {
  streakCount++;
  prefs.setInt('streakCount', streakCount);

  //update longestStreak
  var longest = await _getLongestStreakInt(prefs);
  if (streakCount > longest) {
    prefs.setInt('longestStreak', streakCount);
  }
}

Future<String> getMinutesListened(SharedPreferences prefs) async {
  var streak = prefs.getInt('secsListened');
  if (streak == null)
    return '0';
  else
    return Duration(seconds: streak).inMinutes.toString();
}

Future<int> _getSecondsListened(SharedPreferences prefs) async {
  var streak = prefs.getInt('secsListened');
  if (streak == null)
    return 0;
  else
    return streak;
}

Future<String> getLongestStreak(SharedPreferences prefs) async {
  if (await _getLongestStreakInt(prefs) < await _getCurrentStreakInt(prefs)) {
    return getCurrentStreak(prefs);
  }

  var streak = prefs.getInt('longestStreak');
  if (streak == null)
    return '0';
  else
    return streak.toString();
}

Future<int> _getLongestStreakInt(SharedPreferences prefs) async {
  var streak = prefs.getInt('longestStreak');
  return streak ?? 0;
}

Future<String> getNumSessions(SharedPreferences prefs) async {
  var streak = prefs.getInt('numSessions');
  if (streak == null)
    return '0';
  else
    return streak.toString();
}

Future<int> _getNumSessionsInt(SharedPreferences prefs) async {
  var streak = prefs.getInt('numSessions');
  return streak ?? 0;
}

void incrementNumSessions(SharedPreferences prefs) async {
  var current = await _getNumSessionsInt(prefs);
  current++;
  prefs.setInt('numSessions', current);
}

bool isSameDay(DateTime day1, DateTime day2) {
  return day1.year == day2.year &&
      day1.month == day2.month &&
      day1.day == day2.day;
}
