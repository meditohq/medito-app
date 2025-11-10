import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/audio_completion_tracker.dart';
import 'package:medito/services/home_widget_service.dart';
import 'package:medito/utils/stats_updater.dart';

// Key Rules for a Normal Streak (Without Streak Freezes)
// 1.	Meditating every day increases the streak by 1. Each consecutive day of meditation adds to the streak.
// 2.	Missing a day resets the streak to 0. If the user skips meditation for a full calendar day, the next time they open the app, the streak will be reset.
// 3.	The streak only updates when the app is opened. If the user misses a day but does not open the app, the streak does not reset until they next launch it.
// 4.	Meditation must be completed before midnight. The streak is based on calendar days, so meditating after midnight will count as the next day's session.
// 5.	A new streak starts from 1 after a reset. If the streak is broken, meditating again starts a fresh streak from 1.

// Key Rules for Streak Freezes
// 	1.	Streak freezes prevent a reset but must be activated manually. If a user opens the app after missing a day, they will have the option to use a streak freeze before the streak resets.
// 	2.	Each streak freeze covers only one missed day. If a user misses multiple days, they need an equal number of streak freezes to restore their streak.
// 	3.	Streak freezes apply to specific missed days. If a freeze is used, it fills in a skipped day, making it look like the user meditated on that day.
// 	4.	The app only suggests a streak restoration if the user has enough streak freezes. If a user misses multiple days but does not have enough streak freezes to cover all of them, the app does not offer a partial restoration.
// 	5.	Streak freezes do not apply automatically. Users must choose to use them when they open the app after missing a day.
// 	6.	After using a streak freeze, meditating that day continues the streak. If a streak freeze is applied and the user meditates, the streak progresses as if no days were missed.
//  7. The streak applies to the days before today. The user can use multiple streak freezes to cover multiple days, but it will never restore a previously broken streak, only the current streak can be restored.

class StatsManager {
  static final StatsManager _instance = StatsManager._internal();
  factory StatsManager() => _instance;

  static const _syncLockKey = 'stats_sync_lock';
  static const _syncLockTimeout = Duration(seconds: 30);
  static const _syncTtl = Duration(seconds: 60);

  late StatsService _statsService;
  LocalAllStats? _allStats;
  bool _isInitialized = false;
  DateTime? _testDate;
  DateTime? _lastSyncedAt;
  bool _dirty = false;

  StatsManager._internal();

  Future<bool> _acquireLock() async {
    var prefs = await SharedPreferences.getInstance();
    var lastLockTime = await prefs.getInt(_syncLockKey) ?? 0;
    var now = _getCurrentDate().millisecondsSinceEpoch;

    if (now - lastLockTime > _syncLockTimeout.inMilliseconds) {
      var success = await prefs.setInt(_syncLockKey, now);
      if (!success) return false;

      var checkLock = await prefs.getInt(_syncLockKey);
      return checkLock == now;
    }
    return false;
  }

  Future<void> _releaseLock() async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncLockKey);
  }

  Future<void> initialize() async {
    if (!_isInitialized) {
      _statsService = StatsService(
        httpApiService: HttpApiService(),
        prefs: await SharedPreferences.getInstance(),
      );
      await _loadLastSyncedAt();
      _isInitialized = true;
    }
  }

  Future<void> _loadLastSyncedAt() async {
    try {
      var prefs = await SharedPreferences.getInstance();
      var lastSyncedTimestamp =
          prefs.getInt(SharedPreferenceConstants.statsLastSyncedAt);
      if (lastSyncedTimestamp != null && lastSyncedTimestamp > 0) {
        _lastSyncedAt =
            DateTime.fromMillisecondsSinceEpoch(lastSyncedTimestamp);
      } else {
        _lastSyncedAt = null;
      }
    } catch (e) {
      // Handle case where SharedPreferences isn't initialized (e.g., in some tests)
      // In this case, we just leave _lastSyncedAt as null
      _lastSyncedAt = null;
    }
  }

  Future<void> _saveLastSyncedAt() async {
    try {
      var prefs = await SharedPreferences.getInstance();
      if (_lastSyncedAt != null) {
        await prefs.setInt(SharedPreferenceConstants.statsLastSyncedAt,
            _lastSyncedAt!.millisecondsSinceEpoch);
      } else {
        await prefs.remove(SharedPreferenceConstants.statsLastSyncedAt);
      }
    } catch (e) {
      // Handle case where SharedPreferences isn't initialized (e.g., in some tests)
      // Silently fail - this is OK in test scenarios
    }
  }

  Future<void> sync({bool force = false}) async {
    //dev.log'StatsManager: Starting sync (force: $force)');
    if (!_isInitialized) {
      await initialize();
    }

    // Early return if not forced and not dirty and within TTL
    if (!force) {
      final now = _getCurrentDate();
      final withinTtl =
          _lastSyncedAt != null && now.difference(_lastSyncedAt!) < _syncTtl;
      if (!_dirty && withinTtl) {
        //dev.log'StatsManager: Skipping sync - within TTL and not dirty');
        return;
      }
    }

    for (var i = 0; i < 3; i++) {
      if (await _acquireLock()) {
        try {
          await _doSync();
          return;
        } finally {
          await _releaseLock();
        }
      }
      if (i < 2) await Future.delayed(Duration(milliseconds: 100));
    }

    //dev.log'StatsManager: Failed to acquire sync lock after retries');
  }

  Future<void> _doSync() async {
    //dev.log'StatsManager: Fetching remote stats');
    var remoteStats = await _statsService.fetchAllStats();

    // If we got empty stats but have valid local stats, keep the local stats
    if (remoteStats.totalTracksCompleted == 0 &&
        (remoteStats.audioCompleted?.isEmpty ?? true) &&
        _allStats != null &&
        _allStats!.totalTracksCompleted > 0) {
      //dev.log'StatsManager: Keeping local stats instead of empty remote stats');
      return;
    }

    // Save the remote stats to a temporary variable instead of immediately
    // overwriting _allStats
    var tempRemoteStats = remoteStats;

    // Pass the remote stats to merge instead of overwriting first
    await _merge(tempRemoteStats);

    if (_allStats != null) {
      // Store the current streak values before recalculating
      var currentStreak = _allStats!.streakCurrent;
      var longestStreak = _allStats!.streakLongest;

      // Only recalculate streak in production, not during tests
      try {
        //dev.log'StatsManager: Calculating streak');
        _allStats = calculateStreak(_allStats!);
      } catch (_) {
        _allStats = _allStats!.copyWith(
          streakCurrent: currentStreak,
          streakLongest: longestStreak,
        );
      }

      final newConsistencyScore = calculateConsistencyScore(_allStats!);
      _allStats = _allStats!.copyWith(
        consistencyScore: newConsistencyScore,
      );

      await saveConsistencyScoreHistory(newConsistencyScore);
      await _saveLocalAllStatsToSharedPrefs();
      await _statsService.postStats(_allStats!);
      // Mark as synced and clear dirty flag after successful POST
      _lastSyncedAt = _getCurrentDate();
      await _saveLastSyncedAt();
      _dirty = false;

      // Update home widget
      try {
        await HomeWidgetService.updateWidgetFromStats(_allStats!);
      } catch (e) {
        // Silently fail - widget updates are not critical
      }
    } else {
      throw Exception("Stats are null");
    }

    //dev.log'StatsManager: Sync completed');
  }

  Future<LocalAllStats> get localAllStats async {
    if (_allStats == null) {
      _allStats = await _loadLocalAllStats();

      // Load last synced time from SharedPreferences (not from stats.updated)
      // This is the actual last sync time, not the last modification time
      await _loadLastSyncedAt();

      // If local stats are empty, sync with server to try to get valid stats
      if (_allStats!.totalTracksCompleted == 0 &&
          (_allStats!.audioCompleted?.isEmpty ?? true)) {
        //dev.log'StatsManager: Local stats are empty, syncing with server');
        await sync();
      }
    }
    return _allStats!;
  }

  Future<void> _merge(LocalAllStats remoteStats) async {
    // Check if remote stats contain recent dummy data
    var now = _getCurrentDate();
    var today = DateTime(now.year, now.month, now.day);

    // Check if any dummy tracks are from today
    var hasRecentDummyTracks = remoteStats.audioCompleted?.any((audio) {
          if (!audio.id.startsWith('dummy-track')) return false;

          var trackDate = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
          var trackDay =
              DateTime(trackDate.year, trackDate.month, trackDate.day);

          // Consider tracks from today as recent
          return trackDay.isAtSameMomentAs(today);
        }) ??
        false;

    // If remote stats contain recent dummy data, prefer remote data completely
    if (hasRecentDummyTracks) {
      //dev.log
      //'StatsManager: Remote stats contain recent dummy data, using remote stats only');
      _allStats = remoteStats.copyWith(
        updated: _getCurrentDate().millisecondsSinceEpoch,
      );
      return;
    }

    // Use the current _allStats as localAllStats if available
    LocalAllStats? localAllStats = _allStats;

    // If _allStats is null, try to load from SharedPreferences
    if (localAllStats == null) {
      var prefs = await SharedPreferences.getInstance();
      var localAllStatsJson =
          await prefs.getString(SharedPreferenceConstants.localAllStatsKey);

      if (localAllStatsJson != null && localAllStatsJson != 'null') {
        localAllStats = LocalAllStats.fromJson(
            jsonDecode(localAllStatsJson) as Map<String, dynamic>);
        //dev.log
        //'StatsManager: Loaded local stats from SharedPreferences: ${localAllStats.totalTracksCompleted}');
      } else {
        //dev.log'StatsManager: No local stats found in SharedPreferences');
      }
    } else {
      //dev.log
      //'StatsManager: Using existing _allStats as local stats: ${localAllStats.totalTracksCompleted}');
    }

    // If we have no remote stats but have local stats, use local
    if (remoteStats.totalTracksCompleted == 0) {
      if (localAllStats != null && localAllStats.totalTracksCompleted > 0) {
        //dev.log'StatsManager: Using local stats');
        _allStats = localAllStats.copyWith(
          updated: _getCurrentDate().millisecondsSinceEpoch,
        );
        return;
      }
    }

    // If we have no local stats but have remote stats, use remote
    if (localAllStats == null || localAllStats.totalTracksCompleted == 0) {
      if (remoteStats.totalTracksCompleted > 0) {
        _allStats = remoteStats.copyWith(
          updated: _getCurrentDate().millisecondsSinceEpoch,
        );
        return;
      }
    }

    // If both exist, merge them properly
    if (localAllStats != null) {
      //dev.log'DEBUG - MERGING:');
      //dev.log
      // 'Local audio: ${localAllStats.audioCompleted?.map((a) => a.id).toList()}');
      //dev.log
      // 'Remote audio: ${remoteStats.audioCompleted?.map((a) => a.id).toList()}');

      // Create a combined list of tracks checked
      var combinedTracksChecked = {
        ...localAllStats.tracksChecked ?? [],
        ...remoteStats.tracksChecked ?? []
      }.toList();

      // Deduplicate audio completed entries by ID and timestamp
      final audioCompletedMap = <String, LocalAudioCompleted>{};

      // Process local entries first
      for (final audio in localAllStats.audioCompleted ?? []) {
        final key = '${audio.id}_${audio.timestamp}';
        audioCompletedMap[key] = audio;
      }

      // Process remote entries, overwriting local entries if they exist
      for (final audio in remoteStats.audioCompleted ?? []) {
        final key = '${audio.id}_${audio.timestamp}';
        audioCompletedMap[key] = audio;
      }

      // Convert back to list
      final deduplicatedAudioCompleted = audioCompletedMap.values.toList();

      //dev.log
      //'Deduplicated audio: ${deduplicatedAudioCompleted.map((a) => a.id).toList()}');

      // Create a combined list of freeze usage dates, removing duplicates
      var deduplicatedFreezeUsageDates = {
        ...localAllStats.freezeUsageDates,
        ...remoteStats.freezeUsageDates
      }.toList();

      // Determine which base to use for other properties
      var areRemoteStatsNewer = remoteStats.updated > localAllStats.updated;
      var baseStats = areRemoteStatsNewer ? remoteStats : localAllStats;

      // Update with combined data
      _allStats = baseStats.copyWith(
        audioCompleted: deduplicatedAudioCompleted,
        freezeUsageDates: deduplicatedFreezeUsageDates,
        tracksChecked: combinedTracksChecked,
        updated: _getCurrentDate().millisecondsSinceEpoch,
      );
    } else {
      _allStats = remoteStats;
    }
  }

  LocalAllStats calculateStreak(LocalAllStats allStats) {
    var now = _getCurrentDate();
    var today = DateTime(now.year, now.month, now.day);
    var longestStreak = allStats.streakLongest;

    //dev.log'===== STREAK CALCULATION DEBUG =====');
    //dev.log'Current date for calculation: ${today.toIso8601String()}');
    //dev.log'Initial longest streak: $longestStreak');

    // Early return for empty audio completed list
    if (allStats.audioCompleted == null || allStats.audioCompleted!.isEmpty) {
      //dev.log'No audio entries, returning zero streak');
      return allStats.copyWith(
        streakCurrent: 0,
        streakLongest: longestStreak,
      );
    }

    // Convert audio completed to dates (year-month-day format)
    var audioDates = allStats.audioCompleted!.map((audio) {
      var date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
      return DateTime(date.year, date.month, date.day);
    }).toList();

    // Convert freeze dates (year-month-day format)
    var freezeDates = allStats.freezeUsageDates.map((timestamp) {
      var date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime(date.year, date.month, date.day);
    }).toList();

    // Remove duplicate dates
    audioDates = audioDates.toSet().toList();
    //dev.log
    //'Unique audio dates: ${audioDates.map((d) => d.toIso8601String()).toList()}');

    freezeDates = freezeDates.toSet().toList();
    //dev.log
    // 'Unique freeze dates: ${freezeDates.map((d) => d.toIso8601String()).toList()}');

    // Only use freeze dates that don't already have activity and aren't in the future
    freezeDates = freezeDates
        .where((date) => !audioDates.contains(date) && !date.isAfter(today))
        .toList();
    //dev.log
    //'Filtered freeze dates: ${freezeDates.map((d) => d.toIso8601String()).toList()}');

    // Combine all activity dates and freeze dates
    var allActivityDates = [...audioDates, ...freezeDates];

    // Sort dates in descending order (newest first)
    allActivityDates.sort((a, b) => b.compareTo(a));
    //dev.log
    // 'All activity dates (sorted): ${allActivityDates.map((d) => d.toIso8601String()).toList()}');

    // No dates at all
    if (allActivityDates.isEmpty) {
      //dev.log'No activity dates, returning zero streak');
      return allStats.copyWith(
        streakCurrent: 0,
        streakLongest: longestStreak,
      );
    }

    // Check if there's activity on today
    var hasActivityToday = allActivityDates.any((date) =>
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day);

    // Check yesterday's activity
    var yesterday = today.subtract(const Duration(days: 1));
    //dev.log
    //'Checking for activity on yesterday: ${yesterday.toIso8601String()}');

    var hasActivityYesterday = allActivityDates.any((date) =>
        date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day);
    //dev.log'Has activity yesterday: $hasActivityYesterday');

    // If there's no activity today or yesterday, streak is 0
    if (!hasActivityToday && !hasActivityYesterday) {
      //dev.log'No activity today or yesterday, returning streak = 0');
      return allStats.copyWith(
        streakCurrent: 0,
        streakLongest: longestStreak,
      );
    }

    // If there's activity today but not yesterday, streak is 1
    if (hasActivityToday && !hasActivityYesterday) {
      //dev.log'Activity today but not yesterday, returning streak = 1');
      return allStats.copyWith(
        streakCurrent: 1,
        streakLongest: longestStreak > 1 ? longestStreak : 1,
      );
    }

    // Start with a streak of 1 if we have activity today, or 0 otherwise
    var streak = hasActivityToday ? 1 : 0;

    // Count consecutive days starting from yesterday
    var checkDate = yesterday;
    //dev.log'Starting to count consecutive days from yesterday');

    while (true) {
      var hasActivityOnDate = allActivityDates.any((date) =>
          date.year == checkDate.year &&
          date.month == checkDate.month &&
          date.day == checkDate.day);

      if (hasActivityOnDate) {
        streak++;
        //dev.log
//            'Found activity on ${checkDate.toIso8601String()}, streak = $streak');
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        // No activity on this date, break the streak
        //dev.log
        // 'No activity on ${checkDate.toIso8601String()}, breaking streak');
        break;
      }
    }

    // Update longest streak if necessary
    if (streak > longestStreak) {
      //dev.log'New longest streak: $streak (was $longestStreak)');
      longestStreak = streak;
    }

    //dev.log
    // 'Final streak calculation: current=$streak, longest=$longestStreak');
    //dev.log'===== END STREAK CALCULATION =====');

    return allStats.copyWith(
      streakCurrent: streak,
      streakLongest: longestStreak,
    );
  }

  Future<void> _saveLocalAllStatsToSharedPrefs() async {
    if (_allStats != null && _allStats?.totalTracksCompleted == 0) return;

    //dev.log'StatsManager: Saving local stats');

    var prefs = await SharedPreferences.getInstance();
    if (_allStats != null) {
      await prefs.setString(SharedPreferenceConstants.localAllStatsKey,
          jsonEncode(_allStats!.toJson()));
    }
  }

  Future<LocalAllStats> _loadLocalAllStats() async {
    try {
      var prefs = await SharedPreferences.getInstance();
      var json =
          await prefs.getString(SharedPreferenceConstants.localAllStatsKey);
      if (json != null) {
        var decodedJson = jsonDecode(json);
        if (decodedJson is Map<String, dynamic>) {
          return LocalAllStats.fromJson(decodedJson);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        //dev.log'Error loading local stats: $e');
      }
    }
    return LocalAllStats.empty();
  }

  Future<void> addAudioCompleted(
    LocalAudioCompleted audioCompleted,
    int duration,
  ) async {
    if (_allStats == null) {
      await sync();
    }

    // Mark as dirty since we're about to modify stats
    _dirty = true;

    if (AudioCompletionTracker.checkTrackCrossedMidnight(
      endTimestamp: audioCompleted.timestamp,
      duration: duration,
    )) {
      audioCompleted = audioCompleted.copyWith(
        timestamp: audioCompleted.timestamp - duration,
      );
    }

    // Update stats with the completed audio
    _allStats = AudioCompletionTracker.updateStatsWithCompletedAudio(
      stats: _allStats,
      audioCompleted: audioCompleted,
      duration: duration,
    );

    // Calculate streak and consistency score, then save stats
    if (_allStats != null) {
      _allStats = calculateStreak(_allStats!);
      final newConsistencyScore = calculateConsistencyScore(_allStats!);
      _allStats = _allStats!.copyWith(
        consistencyScore: newConsistencyScore,
      );
      await saveConsistencyScoreHistory(newConsistencyScore);
      await _saveLocalAllStatsToSharedPrefs();
      await _statsService.postStats(_allStats!);
      // Mark as synced and clear dirty flag after successful POST
      _lastSyncedAt = _getCurrentDate();
      await _saveLastSyncedAt();
      _dirty = false;

      // Update home widget
      try {
        await HomeWidgetService.updateWidgetFromStats(_allStats!);
      } catch (e) {
        // Silently fail - widget updates are not critical
      }
    }
  }

  Future<void> addTrackChecked(String? id) async {
    assert(id != null, 'Track ID cannot be null');
    if (_allStats == null) {
      await sync();
    }

    // Mark as dirty since we're about to modify stats
    _dirty = true;

    var updatedTracksChecked = _allStats?.tracksChecked ?? [];
    if (!updatedTracksChecked.contains(id)) {
      updatedTracksChecked.add(id!);

      _allStats = _allStats?.copyWith(
        tracksChecked: updatedTracksChecked,
        updated: _getCurrentDate().millisecondsSinceEpoch,
      );

      await _saveLocalAllStatsToSharedPrefs();
      await _statsService.postStats(_allStats!);
      // Mark as synced and clear dirty flag after successful POST
      _lastSyncedAt = _getCurrentDate();
      await _saveLastSyncedAt();
      _dirty = false;
    }
  }

  Future<void> removeTrackChecked(String trackId) async {
    if (_allStats == null) {
      await sync();
    }

    // Mark as dirty since we're about to modify stats
    _dirty = true;

    var updatedTracksChecked = _allStats?.tracksChecked ?? [];
    if (updatedTracksChecked.remove(trackId)) {
      _allStats = _allStats?.copyWith(
        tracksChecked: updatedTracksChecked,
        updated: _getCurrentDate().millisecondsSinceEpoch,
      );

      await _saveLocalAllStatsToSharedPrefs();
      await _statsService.postStats(_allStats!);
      // Mark as synced and clear dirty flag after successful POST
      _lastSyncedAt = _getCurrentDate();
      await _saveLastSyncedAt();
      _dirty = false;
    }
  }

  Future<void> clearAllStats() async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPreferenceConstants.localAllStatsKey);
    _allStats = LocalAllStats.empty();
  }

  /// Awards a streak freeze to the user
  Future<void> awardStreakFreeze() async {
    if (_allStats == null) {
      await sync();
    }

    // Mark as dirty since we're about to modify stats
    _dirty = true;

    final currentFreezes = _allStats?.streakFreezes ?? 0;
    final maxFreezes = _allStats?.maxStreakFreezes ?? 0;

    if (currentFreezes < maxFreezes) {
      _allStats = _allStats?.copyWith(
        streakFreezes: currentFreezes + 1,
        updated: _getCurrentDate().millisecondsSinceEpoch,
      );

      await _saveLocalAllStatsToSharedPrefs();
      await _statsService.postStats(_allStats!);
      // Mark as synced and clear dirty flag after successful POST
      _lastSyncedAt = _getCurrentDate();
      await _saveLastSyncedAt();
      _dirty = false;
    }
  }

  bool get isInitialized => _isInitialized;

  Future<bool> hasLocalStats() async {
    _allStats ??= await _loadLocalAllStats();

    return _allStats?.audioCompleted?.isNotEmpty == true;
  }

  Future<bool> shouldSuggestStreakFreeze() async {
    if (_allStats == null) {
      await sync();
    }

    final stats = _allStats!;
    final now = _getCurrentDate();
    final today = DateTime(now.year, now.month, now.day);

    // Only check if there's a streak to preserve and user has streak freezes
    if ((stats.audioCompleted?.length ?? 0) > 0 &&
        (stats.streakFreezes ?? 0) > 0) {
      // Convert audio completed dates to DateTime objects
      var audioDates = stats.audioCompleted
              ?.map((audio) {
                var date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
                return DateTime(date.year, date.month, date.day);
              })
              .toSet()
              .toList() ??
          [];

      // Convert existing freeze dates to DateTime objects
      var freezeDates = stats.freezeUsageDates
          .map((timestamp) {
            var date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            return DateTime(date.year, date.month, date.day);
          })
          .toSet()
          .toList();

      // Combine all activity dates
      var allActivityDates = {...audioDates, ...freezeDates}.toList();

      // Check if there's recent activity (including today)
      var hasRecentActivity = allActivityDates.any(
          (date) => !date.isBefore(today.subtract(const Duration(days: 7))));

      if (!hasRecentActivity) {
        // No recent activity, so no streak to preserve
        return false;
      }

      // Check if yesterday has activity
      var yesterday = today.subtract(const Duration(days: 1));
      var hasActivityYesterday = allActivityDates.any((date) =>
          date.year == yesterday.year &&
          date.month == yesterday.month &&
          date.day == yesterday.day);

      // If there's no activity yesterday and we haven't used a freeze for it,
      // we should suggest a streak freeze
      if (!hasActivityYesterday) {
        return true;
      }
    }

    return false;
  }

  Future<bool> applyStreakFreeze() async {
    if (_allStats == null) {
      await sync();
    }

    if (_allStats == null) {
      return false;
    }

    // Mark as dirty since we're about to modify stats
    _dirty = true;

    var availableStreakFreezes = _allStats!.streakFreezes ?? 0;
    if (availableStreakFreezes <= 0) {
      //dev.log'No streak freezes available');
      return false;
    }

    if (_allStats!.audioCompleted?.isEmpty == true) return false;

    // Convert _currentDate to midnight for consistent date comparisons
    var today = DateTime(
        _getCurrentDate().year, _getCurrentDate().month, _getCurrentDate().day);
    var yesterday = today.subtract(const Duration(days: 1));

    // Sort activities by timestamp to ensure proper order
    var audioActivities = [...?_allStats!.audioCompleted];
    audioActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Convert timestamps to DateTime objects for easier comparison
    // Deduplicate dates to match calculateStreak() behavior
    var audioDates = audioActivities
        .map((activity) =>
            DateTime.fromMillisecondsSinceEpoch(activity.timestamp))
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet()
        .toList();

    // Get existing freeze usage dates as DateTime objects for easier comparison
    // Deduplicate dates to match calculateStreak() behavior
    var existingFreezeDates = _allStats!.freezeUsageDates
        .map((timestamp) => DateTime.fromMillisecondsSinceEpoch(timestamp))
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet()
        .toList();

    // Check if yesterday has activity (audio or freeze)
    var yesterdayHasActivity = audioDates.any((date) =>
            date.year == yesterday.year &&
            date.month == yesterday.month &&
            date.day == yesterday.day) ||
        existingFreezeDates.any((date) =>
            date.year == yesterday.year &&
            date.month == yesterday.month &&
            date.day == yesterday.day);

    // If yesterday already has activity (audio or freeze), there's no gap to fill
    // Only apply freezes when there's an actual gap in the streak
    if (yesterdayHasActivity) {
      return false;
    }

    // Verify there's activity today or recently to preserve a streak
    // Don't apply freezes if there's no recent activity (no streak to preserve)
    var hasRecentActivity = audioDates.any((date) =>
            !date.isBefore(today.subtract(const Duration(days: 7)))) ||
        existingFreezeDates.any(
            (date) => !date.isBefore(today.subtract(const Duration(days: 7))));

    if (!hasRecentActivity) {
      // No recent activity, so no streak to preserve
      return false;
    }

    // Find consecutive missed days that need freezes
    var missedDays = <DateTime>[];

    // Start with yesterday and look backwards for gaps
    for (var i = 1; missedDays.length < availableStreakFreezes && i <= 7; i++) {
      var dayToCheck = today.subtract(Duration(days: i));

      // Check if this day already has activity or a freeze
      var hasAudioActivity = audioDates.any((date) =>
          date.year == dayToCheck.year &&
          date.month == dayToCheck.month &&
          date.day == dayToCheck.day);

      var hasFreeze = existingFreezeDates.any((date) =>
          date.year == dayToCheck.year &&
          date.month == dayToCheck.month &&
          date.day == dayToCheck.day);

      if (!hasAudioActivity && !hasFreeze) {
        // This is a missed day - add it to our list
        missedDays.add(dayToCheck);
      } else if (missedDays.isEmpty) {
        // If we find a day with activity/freeze but haven't found gaps yet,
        // continue looking for gaps
        continue;
      } else if (hasAudioActivity || hasFreeze) {
        // If we've already found gaps and now found activity,
        // we've found all consecutive gaps to fill
        break;
      }
    }

    // If we didn't find any days to freeze, return false
    if (missedDays.isEmpty) {
      return false;
    }

    // Limit to available freezes
    if (missedDays.length > availableStreakFreezes) {
      missedDays = missedDays.sublist(0, availableStreakFreezes);
    }

    // Apply freezes to the missed days
    var newFreezeUsageDates = [..._allStats!.freezeUsageDates];

    for (var missedDay in missedDays) {
      newFreezeUsageDates.add(missedDay.millisecondsSinceEpoch);
    }

    // Update stats and calculate new streak
    var updatedStats = _allStats!.copyWith(
      streakFreezes: availableStreakFreezes - missedDays.length,
      freezeUsageDates: newFreezeUsageDates,
      updated: _getCurrentDate().millisecondsSinceEpoch,
    );

    _allStats = updatedStats;

    // Calculate the new streak with freezes applied
    _allStats = calculateStreak(_allStats!);
    final newConsistencyScore = calculateConsistencyScore(_allStats!);
    _allStats = _allStats!.copyWith(
      consistencyScore: newConsistencyScore,
    );
    await saveConsistencyScoreHistory(newConsistencyScore);

    await _saveLocalAllStatsToSharedPrefs();
    await _statsService.postStats(_allStats!);
    // Mark as synced and clear dirty flag after successful POST
    _lastSyncedAt = _getCurrentDate();
    await _saveLastSyncedAt();
    _dirty = false;

    // Update home widget
    try {
      await HomeWidgetService.updateWidgetFromStats(_allStats!);
    } catch (e) {
      // Silently fail - widget updates are not critical
    }

    return true;
  }

  double calculateConsistencyScore(LocalAllStats allStats) {
    var now = _getCurrentDate();
    var today = DateTime(now.year, now.month, now.day);

    // Early return for empty audio completed list
    if (allStats.audioCompleted == null || allStats.audioCompleted!.isEmpty) {
      return 0.0;
    }

    // Convert audio completed to dates (year-month-day format)
    var audioDates = allStats.audioCompleted!.map((audio) {
      var date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
      return DateTime(date.year, date.month, date.day);
    }).toList();

    // Remove duplicate dates and future dates
    audioDates =
        audioDates.where((date) => !date.isAfter(today)).toSet().toList();

    // If no valid dates, return 0
    if (audioDates.isEmpty) {
      return 0.0;
    }

    // Sort dates in ascending order to find first session
    audioDates.sort();
    var firstSessionDate = audioDates.first;

    // Calculate days since first session (inclusive)
    var daysSinceFirstSession = today.difference(firstSessionDate).inDays + 1;

    // If first session is today, return 1.0 if meditated today, 0.0 otherwise
    if (daysSinceFirstSession == 1) {
      return audioDates.any((date) => date.isAtSameMomentAs(today)) ? 1.0 : 0.0;
    }

    // For users with less than 30 days history
    if (daysSinceFirstSession < 30) {
      var meditatedDays = audioDates.length;
      return (meditatedDays / daysSinceFirstSession).clamp(0.0, 1.0);
    }

    // For users with 30+ days history, only look at last 30 days
    var daysToCheck =
        List.generate(30, (index) => today.subtract(Duration(days: index)));
    var meditatedDaysInRange = daysToCheck
        .where((date) => audioDates.any((audioDate) =>
            audioDate.year == date.year &&
            audioDate.month == date.month &&
            audioDate.day == date.day))
        .length;

    return (meditatedDaysInRange / 30.0);
  }

  // Test helpers
  @visibleForTesting
  void setStatsForTesting(LocalAllStats stats) {
    _allStats = stats;
  }

  @visibleForTesting
  void setStatsServiceForTesting(StatsService service) {
    _statsService = service;
  }

  @visibleForTesting
  LocalAllStats? get currentStats => _allStats;

  void setCurrentDateForTesting(DateTime date) {
    _testDate = date;
  }

  @visibleForTesting
  void resetForTesting() {
    _allStats = null;
    _isInitialized = false;
    _testDate = null;
    _lastSyncedAt = null;
    _dirty = false;
  }

  @visibleForTesting
  Future<void> setLastSyncedAtForTesting(DateTime? dateTime) async {
    _lastSyncedAt = dateTime;
    if (dateTime != null) {
      var prefs = await SharedPreferences.getInstance();
      await prefs.setInt(SharedPreferenceConstants.statsLastSyncedAt,
          dateTime.millisecondsSinceEpoch);
    } else {
      var prefs = await SharedPreferences.getInstance();
      await prefs.remove(SharedPreferenceConstants.statsLastSyncedAt);
    }
  }

  DateTime _getCurrentDate() {
    return _testDate ?? DateTime.now();
  }

  // Test helpers
  @visibleForTesting
  Future<void> initializeForTesting({StatsService? statsService}) async {
    if (!_isInitialized) {
      _statsService = statsService ??
          StatsService(
            httpApiService: HttpApiService(),
            prefs: await SharedPreferences.getInstance(),
          );
      await _loadLastSyncedAt();
      _isInitialized = true;
    }
  }
}
