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
import 'package:medito/utils/logger.dart';
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
// 	3.	Streak freezes apply to specific missed days. If a freeze is used, it bridges the gap so the streak is not broken, but does not add to the streak counter since no meditation was completed.
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
  late SharedPreferences _prefs;
  LocalAllStats? _allStats;
  bool _isInitialized = false;
  Completer<void>? _initCompleter;
  DateTime? _testDate;
  DateTime? _lastSyncedAt;
  bool _dirty = false;

  StatsManager._internal();

  Future<bool> _acquireLock() async {
    var prefs = _prefs;
    var lastLockTime = prefs.getInt(_syncLockKey) ?? 0;
    var now = _getCurrentDate().millisecondsSinceEpoch;

    if (now - lastLockTime > _syncLockTimeout.inMilliseconds) {
      var success = await prefs.setInt(_syncLockKey, now);
      if (!success) return false;

      var checkLock = prefs.getInt(_syncLockKey);
      return checkLock == now;
    }
    return false;
  }

  Future<void> _releaseLock() async {
    await _prefs.remove(_syncLockKey);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    _initCompleter = Completer<void>();
    try {
      _prefs = await SharedPreferences.getInstance();
      _statsService = StatsService(
        httpApiService: HttpApiService(),
        prefs: _prefs,
      );
      await _loadLastSyncedAt(_prefs);
      _isInitialized = true;
      _initCompleter!.complete();
    } catch (e) {
      AppLogger.e('STATS_MANAGER', 'Initialization failed', e);
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> _loadLastSyncedAt([SharedPreferences? prefsArg]) async {
    try {
      var prefs = prefsArg ?? _prefs;
      var lastSyncedTimestamp = prefs.getInt(
        SharedPreferenceConstants.statsLastSyncedAt,
      );
      if (lastSyncedTimestamp != null && lastSyncedTimestamp > 0) {
        _lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(
          lastSyncedTimestamp,
        );
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
      var prefs = _prefs;
      if (_lastSyncedAt != null) {
        await prefs.setInt(
          SharedPreferenceConstants.statsLastSyncedAt,
          _lastSyncedAt!.millisecondsSinceEpoch,
        );
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
    // but still recalculate streak against current date
    if (remoteStats.totalTracksCompleted == 0 &&
        (remoteStats.audioCompleted?.isEmpty ?? true) &&
        _allStats != null &&
        _allStats!.totalTracksCompleted > 0) {
      //dev.log'StatsManager: Keeping local stats instead of empty remote stats');
      _allStats = calculateStreak(_allStats!);
      final newConsistencyScore = calculateConsistencyScore(_allStats!);
      _allStats = _allStats!.copyWith(consistencyScore: newConsistencyScore);
      await _saveLocalAllStatsToSharedPrefs();
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
      _allStats = _allStats!.copyWith(consistencyScore: newConsistencyScore);

      await saveConsistencyScoreHistory(newConsistencyScore);
      await _saveLocalAllStatsToSharedPrefs();
      await _statsService.postStats(_allStats!);
      // Mark as synced and clear dirty flag after successful POST
      _lastSyncedAt = _getCurrentDate();
      await _saveLastSyncedAt();
      _dirty = false;

      // Update home widget (fire-and-forget to avoid blocking)
      HomeWidgetService.updateWidgetFromStats(_allStats!).catchError((e) {
        // Silently fail - widget updates are not critical
      });
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
    var hasRecentDummyTracks =
        remoteStats.audioCompleted?.any((audio) {
          if (!audio.id.startsWith('dummy-track')) return false;

          var trackDate = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
          var trackDay = DateTime(
            trackDate.year,
            trackDate.month,
            trackDate.day,
          );

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
      var prefs = _prefs;
      var localAllStatsJson = prefs.getString(
        SharedPreferenceConstants.localAllStatsKey,
      );

      if (localAllStatsJson != null && localAllStatsJson != 'null') {
        localAllStats = LocalAllStats.fromJson(
          jsonDecode(localAllStatsJson) as Map<String, dynamic>,
        );
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
        ...remoteStats.tracksChecked ?? [],
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
        ...remoteStats.freezeUsageDates,
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

    // Build a map of calendar day → hasRealSession.
    // true  = at least one real meditation that day
    // false = only freeze entries that day (bridges gap, doesn't count)
    final activityByDate = <DateTime, bool>{};

    for (final entry in allStats.audioCompleted ?? []) {
      final date = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
      final day = DateTime(date.year, date.month, date.day);
      if (day.isAfter(today)) continue;
      final isReal = !isFreezeSession(entry);
      // Once a day is marked real, keep it real even if a freeze also exists
      activityByDate[day] = (activityByDate[day] ?? false) || isReal;
    }

    // Legacy freeze dates (local-only field, kept for backwards compatibility)
    for (final ts in allStats.freezeUsageDates) {
      final date = DateTime.fromMillisecondsSinceEpoch(ts);
      final day = DateTime(date.year, date.month, date.day);
      if (!day.isAfter(today)) {
        activityByDate[day] ??= false;
      }
    }

    // No real sessions at all → streak is 0
    if (!activityByDate.values.any((isReal) => isReal)) {
      return allStats.copyWith(streakCurrent: 0, streakLongest: longestStreak);
    }

    // DST-safe yesterday
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    final hasActivityToday = activityByDate.containsKey(today);
    final hasActivityYesterday = activityByDate.containsKey(yesterday);

    // Streak is 0 if neither today nor yesterday has any activity
    if (!hasActivityToday && !hasActivityYesterday) {
      return allStats.copyWith(streakCurrent: 0, streakLongest: longestStreak);
    }

    // Activity today but not yesterday → fresh streak of 1 (or 0 if freeze-only today)
    if (hasActivityToday && !hasActivityYesterday) {
      final streak = (activityByDate[today]!) ? 1 : 0;
      return allStats.copyWith(
        streakCurrent: streak,
        streakLongest: longestStreak > streak ? longestStreak : streak,
      );
    }

    // Walk backwards counting consecutive days.
    // Real days increment the counter; freeze-only days bridge the gap without incrementing.
    var streak = (activityByDate[today] ?? false) ? 1 : 0;
    var checkDate = yesterday;

    while (activityByDate.containsKey(checkDate)) {
      if (activityByDate[checkDate]!) streak++;
      checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
    }

    if (streak > longestStreak) longestStreak = streak;

    return allStats.copyWith(
      streakCurrent: streak,
      streakLongest: longestStreak,
    );
  }

  Future<void> _saveLocalAllStatsToSharedPrefs() async {
    if (_allStats != null && _allStats?.totalTracksCompleted == 0) return;

    //dev.log'StatsManager: Saving local stats');

    var prefs = _prefs;
    if (_allStats != null) {
      await prefs.setString(
        SharedPreferenceConstants.localAllStatsKey,
        jsonEncode(_allStats!.toJson()),
      );
    }
  }

  Future<LocalAllStats> _loadLocalAllStats() async {
    try {
      var prefs = _prefs;
      var json = prefs.getString(SharedPreferenceConstants.localAllStatsKey);
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
      _allStats = _allStats!.copyWith(consistencyScore: newConsistencyScore);
      await saveConsistencyScoreHistory(newConsistencyScore);
      await _saveLocalAllStatsToSharedPrefs();
      await _statsService.postStats(_allStats!);
      // Mark as synced and clear dirty flag after successful POST
      _lastSyncedAt = _getCurrentDate();
      await _saveLastSyncedAt();
      _dirty = false;

      // Update home widget (fire-and-forget to avoid blocking)
      HomeWidgetService.updateWidgetFromStats(_allStats!).catchError((e) {
        // Silently fail - widget updates are not critical
      });
    }
  }

  Future<void> removeAudioCompleted(LocalAudioCompleted session) async {
    if (_allStats == null) {
      await sync();
    }
    if (_allStats == null) return;

    final currentList = _allStats!.audioCompleted ?? [];
    final updatedList = currentList
        .where((a) =>
            !(a.id == session.id && a.timestamp == session.timestamp))
        .toList();

    if (updatedList.length == currentList.length) {
      // Nothing matched — don't write an update
      return;
    }

    _dirty = true;

    final newTotalTracks = (_allStats!.totalTracksCompleted - 1).clamp(0, 1 << 31);

    _allStats = _allStats!.copyWith(
      audioCompleted: updatedList,
      totalTracksCompleted: newTotalTracks,
      updated: _getCurrentDate().millisecondsSinceEpoch,
    );

    _allStats = calculateStreak(_allStats!);
    final newConsistencyScore = calculateConsistencyScore(_allStats!);
    _allStats = _allStats!.copyWith(consistencyScore: newConsistencyScore);
    await saveConsistencyScoreHistory(newConsistencyScore);
    await _saveLocalAllStatsToSharedPrefs();
    await _statsService.postStats(_allStats!);
    _lastSyncedAt = _getCurrentDate();
    await _saveLastSyncedAt();
    _dirty = false;

    HomeWidgetService.updateWidgetFromStats(_allStats!).catchError((e) {
      // Silently fail - widget updates are not critical
    });
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
    var prefs = _prefs;
    await prefs.remove(SharedPreferenceConstants.localAllStatsKey);
    _allStats = LocalAllStats.empty();
    // Reset sync timestamp so that sync will run after clearing
    _lastSyncedAt = null;
    await _saveLastSyncedAt();
  }

  bool get isInitialized => _isInitialized;

  Future<bool> hasLocalStats() async {
    _allStats ??= await _loadLocalAllStats();

    return _allStats?.audioCompleted?.isNotEmpty == true;
  }

  double calculateConsistencyScore(LocalAllStats allStats) {
    var now = _getCurrentDate();
    var today = DateTime(now.year, now.month, now.day);

    if (allStats.audioCompleted == null || allStats.audioCompleted!.isEmpty) {
      return 0.0;
    }

    var audioDates = allStats.audioCompleted!.map((audio) {
      var date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
      return DateTime(date.year, date.month, date.day);
    }).toList();

    audioDates = audioDates
        .where((date) => !date.isAfter(today))
        .toSet()
        .toList();

    var freezeDates = allStats.freezeUsageDates.map((timestamp) {
      var date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime(date.year, date.month, date.day);
    }).toList();

    freezeDates = freezeDates
        .where((date) => !date.isAfter(today) && !audioDates.contains(date))
        .toSet()
        .toList();

    var allActivityDates = {...audioDates, ...freezeDates}.toList();

    if (allActivityDates.isEmpty) {
      return 0.0;
    }

    allActivityDates.sort();
    var firstSessionDate = allActivityDates.first;
    var daysSinceFirstSession = today.difference(firstSessionDate).inDays + 1;

    if (daysSinceFirstSession == 1) {
      return allActivityDates.any((date) => date.isAtSameMomentAs(today))
          ? 1.0
          : 0.0;
    }

    // Bootstrap phase: simple ratio for the first 30 days
    if (daysSinceFirstSession < 30) {
      return (allActivityDates.length / daysSinceFirstSession).clamp(0.0, 1.0);
    }

    // EMA phase: replay history day by day starting from day 30,
    // seeding with the ratio at day 29.
    const alpha = 0.1;
    const gracePenalty = 0.5; // value used for a single isolated missed day

    var day29 = firstSessionDate.add(const Duration(days: 28));
    var activeDaysAtDay29 = allActivityDates
        .where((d) => !d.isAfter(day29))
        .length;
    var ema = activeDaysAtDay29 / 29.0;

    var day30 = firstSessionDate.add(const Duration(days: 29));
    var currentDay = day30;

    while (!currentDay.isAfter(today)) {
      var hadActivity = allActivityDates.any(
        (d) =>
            d.year == currentDay.year &&
            d.month == currentDay.month &&
            d.day == currentDay.day,
      );

      double dayValue;
      if (hadActivity) {
        dayValue = 1.0;
      } else {
        var prevDay = currentDay.subtract(const Duration(days: 1));
        var nextDay = currentDay.add(const Duration(days: 1));
        var prevActive = allActivityDates.any(
          (d) =>
              d.year == prevDay.year &&
              d.month == prevDay.month &&
              d.day == prevDay.day,
        );
        var nextActive = nextDay.isAfter(today)
            ? false
            : allActivityDates.any(
                (d) =>
                    d.year == nextDay.year &&
                    d.month == nextDay.month &&
                    d.day == nextDay.day,
              );
        // Single isolated miss gets half penalty; consecutive misses get full penalty
        dayValue = (prevActive || nextActive) ? gracePenalty : 0.0;
      }

      ema = alpha * dayValue + (1 - alpha) * ema;
      currentDay = currentDay.add(const Duration(days: 1));
    }

    return ema.clamp(0.0, 1.0);
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
    _initCompleter = null;
    _testDate = null;
    _lastSyncedAt = null;
    _dirty = false;
  }

  @visibleForTesting
  Future<void> setLastSyncedAtForTesting(DateTime? dateTime) async {
    _lastSyncedAt = dateTime;
    if (dateTime != null) {
      await _prefs.setInt(
        SharedPreferenceConstants.statsLastSyncedAt,
        dateTime.millisecondsSinceEpoch,
      );
    } else {
      await _prefs.remove(SharedPreferenceConstants.statsLastSyncedAt);
    }
  }

  DateTime _getCurrentDate() {
    return _testDate ?? DateTime.now();
  }

  // Test helpers
  @visibleForTesting
  Future<void> initializeForTesting({StatsService? statsService}) async {
    if (!_isInitialized) {
      _prefs = await SharedPreferences.getInstance();
      _statsService =
          statsService ??
          StatsService(httpApiService: HttpApiService(), prefs: _prefs);
      await _loadLastSyncedAt(_prefs);
      _isInitialized = true;
    }
  }
}
