import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:medito/constants/strings/shared_preference_constants.dart';

class AppHistoryService {
  static Future<void> recordCurrentVersion(
    SharedPreferences prefs, {
    required String version,
    required String buildNumber,
  }) async {
    final list = getVersionHistory(prefs);
    final alreadyRecorded = list.any(
      (e) => e['version'] == version && e['buildNumber'] == buildNumber,
    );
    if (alreadyRecorded) return;

    list.add({
      'version': version,
      'buildNumber': buildNumber,
      'firstSeenAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(
      SharedPreferenceConstants.installedVersionHistory,
      jsonEncode(list),
    );
  }

  static List<Map<String, dynamic>> getVersionHistory(SharedPreferences prefs) {
    final raw = prefs.getString(SharedPreferenceConstants.installedVersionHistory);
    return _decodeList(raw);
  }

  static Future<void> recordSignIn(
    SharedPreferences prefs, {
    required String userId,
    String? email,
  }) async {
    final list = getSignInHistory(prefs);
    final alreadyRecorded =
        list.any((e) => e['userId'] == userId && e['email'] == email);
    if (alreadyRecorded) return;

    list.add({
      'userId': userId,
      'email': email,
      'signedInAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(
      SharedPreferenceConstants.signedInUserHistory,
      jsonEncode(list),
    );
  }

  static List<Map<String, dynamic>> getSignInHistory(SharedPreferences prefs) {
    final raw = prefs.getString(SharedPreferenceConstants.signedInUserHistory);
    return _decodeList(raw);
  }

  static String getVersionHistoryBase64(SharedPreferences prefs) =>
      _encodeBase64(getVersionHistory(prefs));

  static String getSignInHistoryBase64(SharedPreferences prefs) =>
      _encodeBase64(getSignInHistory(prefs));

  static String _encodeBase64(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return '';
    return base64Encode(utf8.encode(jsonEncode(list)));
  }

  static List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
