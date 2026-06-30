import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/services/home_widget_service.dart';

part 'stats_provider.g.dart';

final statsManagerProvider = Provider<StatsManager>((ref) => StatsManager());

/// Provides the best-available user ID (auth first, then SharedPreferences)
final userIdProvider = Provider<String?>((ref) {
  final authRepository = ref.watch(authRepositorySyncProvider);
  final idFromAuth = authRepository.currentUser?.id;
  if (idFromAuth != null && idFromAuth.isNotEmpty) {
    return idFromAuth;
  }
  return ref
      .watch(sharedPreferencesProvider)
      .getString(SharedPreferenceConstants.userId);
});

final editStatsUrlProvider = FutureProvider<String>((ref) async {
  var clientId = ref.watch(userIdProvider) ?? '';

  // If clientId is empty, try to get it directly from SharedPreferences
  if (clientId.isEmpty) {
    clientId =
        ref
            .read(sharedPreferencesProvider)
            .getString(SharedPreferenceConstants.userId) ??
        '';
    AppLogger.d(
      'STATS_PROVIDER',
      'Using fallback clientId from SharedPreferences: $clientId',
    );
  }

  final stats = ref.watch(statsProvider).value;
  final deviceInfo = ref.watch(deviceAndAppInfoProvider).value;

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
    AppLogger.d('STATS_PROVIDER', 'StatsNotifier: Building');

    return _fetchStatsWithRetry();
  }

  Future<LocalAllStats> _fetchStatsWithRetry({bool force = false}) async {
    // Try to fetch valid stats with retries
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      var stats = await _fetchStats(force: force);

      // If we have valid stats, return them
      if (stats.totalTracksCompleted > 0 ||
          (stats.audioCompleted?.isNotEmpty ?? false)) {
        AppLogger.d(
          'STATS_PROVIDER',
          'StatsNotifier: Got valid stats on attempt ${attempt + 1}',
        );

        return stats;
      }

      // If this isn't the last attempt, wait before retrying
      if (attempt < _maxRetries) {
        AppLogger.d(
          'STATS_PROVIDER',
          'StatsNotifier: Empty stats on attempt ${attempt + 1}, retrying...',
        );
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        AppLogger.d(
          'STATS_PROVIDER',
          'StatsNotifier: Still empty stats after all retries',
        );
      }
    }

    // If we still have empty stats after all retries, return them

    return _fetchStats(force: force);
  }

  Future<LocalAllStats> _fetchStats({bool force = false}) async {
    var statsManager = ref.read(statsManagerProvider);

    try {
      var authRepository = ref.read(authRepositorySyncProvider);
      if (authRepository.currentUser != null) {
        AppLogger.d(
          'STATS_PROVIDER',
          'StatsNotifier: Starting fetch (force: $force)',
        );
        await statsManager.initialize();
        // Force sync when refreshing to get latest data from server across devices
        await statsManager.sync(force: force);
      } else {
        AppLogger.d(
          'STATS_PROVIDER',
          'StatsNotifier: User not signed in, skipping stats sync',
        );
      }

      return await statsManager.localAllStats;
    } catch (error) {
      AppLogger.e('STATS_PROVIDER', 'StatsNotifier: Error during fetch', error);

      if (error is AppError) {
        rethrow;
      }
      throw const UnknownError();
    }
  }

  Future<void> refresh() async {
    AppLogger.d('STATS_PROVIDER', 'StatsNotifier: Starting refresh');
    if (_lastRefresh != null) {
      var timeSinceLastRefresh = DateTime.now().difference(_lastRefresh!);
      if (timeSinceLastRefresh < _minRefreshInterval) {
        AppLogger.d(
          'STATS_PROVIDER',
          'StatsNotifier: Skipping refresh - too soon',
        );

        return;
      }
    }

    _lastRefresh = DateTime.now();
    state = await AsyncValue.guard(() => _fetchStatsWithRetry(force: true));
    AppLogger.d('STATS_PROVIDER', 'StatsNotifier: Refresh completed');

    // Update home widget if stats are available (fire-and-forget to avoid blocking)
    if (state.hasValue && state.value != null) {
      // Don't await widget updates to prevent blocking the UI thread
      // Widget updates are non-critical and should not cause ANRs
      HomeWidgetService.updateWidgetFromStats(state.value!).catchError((e) {
        // Silently fail - widget updates are not critical
      });
    }
  }

  Future<void> refreshFromLocal() async {
    AppLogger.d(
      'STATS_PROVIDER',
      'StatsNotifier: Starting refresh from local stats',
    );
    var statsManager = ref.read(statsManagerProvider);

    try {
      await statsManager.initialize();
      var localStats = await statsManager.localAllStats;
      state = AsyncValue.data(localStats);
      AppLogger.d(
        'STATS_PROVIDER',
        'StatsNotifier: Refresh from local completed',
      );

      // Update home widget (fire-and-forget to avoid blocking)
      HomeWidgetService.updateWidgetFromStats(localStats).catchError((e) {
        // Silently fail - widget updates are not critical
      });
    } catch (error) {
      AppLogger.e(
        'STATS_PROVIDER',
        'StatsNotifier: Error during refresh from local',
        error,
      );

      if (error is AppError) {
        state = AsyncValue.error(error, StackTrace.current);
      } else {
        state = AsyncValue.error(const UnknownError(), StackTrace.current);
      }
    }
  }
}
