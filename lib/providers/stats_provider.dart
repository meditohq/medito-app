import 'dart:developer' as dev;

import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';

part 'stats_provider.g.dart';

final statsManagerProvider = Provider<StatsManager>((ref) => StatsManager());

final statsProvider = AsyncNotifierProvider<StatsNotifier, LocalAllStats>(() {
  return StatsNotifier();
});

/// Provides the best-available user ID (auth first, then SharedPreferences)
final userIdProvider = FutureProvider<String?>((ref) async {
  final authRepository = ref.watch(authRepositorySyncProvider);
  final idFromAuth = authRepository.currentUser?.id;
  if (idFromAuth != null && idFromAuth.isNotEmpty) {
    return idFromAuth;
  }

  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(SharedPreferenceConstants.userId);
});

final editStatsUrlProvider = FutureProvider<String>((ref) async {
  var clientId = ref.watch(userIdProvider).value ?? '';

  // If clientId is empty, try to get it directly from SharedPreferences
  if (clientId.isEmpty) {
    final prefs = await SharedPreferences.getInstance();
    clientId = prefs.getString(SharedPreferenceConstants.userId) ?? '';
    dev.log('Using fallback clientId from SharedPreferences: $clientId');
  }

  final stats = ref.watch(statsProvider).valueOrNull;
  final deviceInfo = ref.watch(deviceAndAppInfoProvider).valueOrNull;

  if (deviceInfo == null || stats == null) {
    return '$editStatsUrl?clientid=$clientId';
  }

  final timeListened = (stats.totalTimeListened / 60000).round();
  final timezone = DateTime.now().timeZoneName;
  final os = deviceInfo.os;
  final platform = deviceInfo.platform;
  final appVersion = deviceInfo.appVersion;
  final model = deviceInfo.model;

  return '$editStatsUrl?clientid=$clientId'
      '&streakcurrent=${stats.streakCurrent}'
      '&streaklongest=${stats.streakLongest}'
      '&trackscompleted=${stats.totalTracksCompleted}'
      '&timelistened=$timeListened'
      '&timezone=$timezone'
      '&os=$os'
      '&platform=$platform'
      '&appVersion=$appVersion'
      '&model=$model';
});

@Riverpod(keepAlive: true)
class StatsNotifier extends AsyncNotifier<LocalAllStats> {
  static DateTime? _lastRefresh;
  static const _minRefreshInterval = Duration(seconds: 2);
  static const _maxRetries = 2;

  @override
  Future<LocalAllStats> build() async {
    dev.log('StatsNotifier: Building');
    return _fetchStatsWithRetry();
  }

  Future<LocalAllStats> _fetchStatsWithRetry() async {
    // Try to fetch valid stats with retries
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      var stats = await _fetchStats();

      // If we have valid stats, return them
      if (stats.totalTracksCompleted > 0 ||
          (stats.audioCompleted?.isNotEmpty ?? false)) {
        dev.log('StatsNotifier: Got valid stats on attempt ${attempt + 1}');
        return stats;
      }

      // If this isn't the last attempt, wait before retrying
      if (attempt < _maxRetries) {
        dev.log(
            'StatsNotifier: Empty stats on attempt ${attempt + 1}, retrying...');
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        dev.log('StatsNotifier: Still empty stats after all retries');
      }
    }

    // If we still have empty stats after all retries, return them
    return _fetchStats();
  }

  Future<LocalAllStats> _fetchStats() async {
    var statsManager = ref.read(statsManagerProvider);

    try {
      var authRepository = ref.read(authRepositorySyncProvider);
      if (authRepository.currentUser != null) {
        dev.log('StatsNotifier: Starting fetch');
        await statsManager.initialize();
        // Always sync on startup to ensure we have latest data from server
        // The sync() method will skip if within TTL and not dirty, which is fine
        await statsManager.sync(force: false);
      } else {
        dev.log('StatsNotifier: User not signed in, skipping stats sync');
      }

      return await statsManager.localAllStats;
    } catch (error) {
      dev.log('StatsNotifier: Error during fetch', error: error);

      if (error is AppError) {
        rethrow;
      }
      throw const UnknownError();
    }
  }

  Future<void> refresh() async {
    dev.log('StatsNotifier: Starting refresh');
    if (_lastRefresh != null) {
      var timeSinceLastRefresh = DateTime.now().difference(_lastRefresh!);
      if (timeSinceLastRefresh < _minRefreshInterval) {
        dev.log('StatsNotifier: Skipping refresh - too soon');
        return;
      }
    }

    _lastRefresh = DateTime.now();
    state = await AsyncValue.guard(() => _fetchStatsWithRetry());
    dev.log('StatsNotifier: Refresh completed');
  }

  Future<void> refreshFromLocal() async {
    dev.log('StatsNotifier: Starting refresh from local stats');
    var statsManager = ref.read(statsManagerProvider);

    try {
      await statsManager.initialize();
      var localStats = await statsManager.localAllStats;
      state = AsyncValue.data(localStats);
      dev.log('StatsNotifier: Refresh from local completed');
    } catch (error) {
      dev.log('StatsNotifier: Error during refresh from local', error: error);

      if (error is AppError) {
        state = AsyncValue.error(error, StackTrace.current);
      } else {
        state = AsyncValue.error(const UnknownError(), StackTrace.current);
      }
    }
  }
}
