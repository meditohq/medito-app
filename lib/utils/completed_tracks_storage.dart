import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/types/type_constants.dart';
import 'logger.dart';

/// Helper class to manage storage of completed track data in SharedPreferences
class CompletedTracksStorage {
  static const String completedTracksKey = 'completed_tracks_data';

  final SharedPreferences _prefs;

  CompletedTracksStorage(this._prefs);

  /// Creates a CompletedTracksStorage instance by obtaining SharedPreferences
  static Future<CompletedTracksStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return CompletedTracksStorage(prefs);
  }

  /// Add a new completed track payload to storage
  Future<void> addCompletedTrack(Map<String, dynamic> payload) async {
    try {
      final currentList = _prefs.getStringList(completedTracksKey) ?? [];
      currentList.add(jsonEncode(payload));

      await _prefs.setStringList(completedTracksKey, currentList);
      final trackId = payload[TypeConstants.trackIdKey];
      AppLogger.d(
        'STORAGE',
        'Stored track completion for later processing: $trackId',
      );
    } catch (e) {
      AppLogger.e('STORAGE', 'Error storing completed track', e);
    }
  }

  /// Get all pending completed tracks
  List<String> getPendingTracks() {
    return _prefs.getStringList(completedTracksKey) ?? [];
  }

  /// Update the list of pending tracks (typically to remove processed ones)
  Future<void> updatePendingTracks(List<String> tracks) async {
    await _prefs.setStringList(completedTracksKey, tracks);
  }

  /// Returns whether there are any pending tracks
  bool hasPendingTracks() {
    final pendingTracks = _prefs.getStringList(completedTracksKey) ?? [];
    return pendingTracks.isNotEmpty;
  }

  /// Clear all pending tracks
  Future<void> clearPendingTracks() async {
    await _prefs.setStringList(completedTracksKey, []);
  }
}
