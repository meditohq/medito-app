import 'dart:convert';

import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saves a consistency score entry to historical data.
///
/// Each entry contains the score and datetime timestamp.
Future<void> saveConsistencyScoreHistory(double consistencyScore) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(
      SharedPreferenceConstants.consistencyScoreHistory,
    );

    List<Map<String, dynamic>> historyList = [];
    if (historyJson != null && historyJson.isNotEmpty) {
      final decoded = jsonDecode(historyJson) as List<dynamic>;
      historyList = decoded
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }

    final entry = {
      'score': consistencyScore,
      'datetime': DateTime.now().millisecondsSinceEpoch,
    };

    historyList.add(entry);

    await prefs.setString(
      SharedPreferenceConstants.consistencyScoreHistory,
      jsonEncode(historyList),
    );

    AppLogger.d(
      'STATS',
      'Saved consistency score history entry: $consistencyScore at ${DateTime.now()}',
    );
  } catch (e) {
    AppLogger.e('STATS', 'Failed to save consistency score history', e);
  }
}

/// Retrieves historical consistency score data.
///
/// Returns a list of maps with 'score' and 'datetime' keys.
Future<List<Map<String, dynamic>>> getConsistencyScoreHistory() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(
      SharedPreferenceConstants.consistencyScoreHistory,
    );

    if (historyJson == null || historyJson.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(historyJson) as List<dynamic>;
    return decoded.map((item) => item as Map<String, dynamic>).toList();
  } catch (e) {
    AppLogger.e('STATS', 'Failed to get consistency score history', e);
    return [];
  }
}
