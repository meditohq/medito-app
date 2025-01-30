import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/views/settings/settings_screen.dart';

final statsManagerProvider = Provider<StatsManager>((ref) => StatsManager());

final statsProvider = AsyncNotifierProvider<StatsNotifier, LocalAllStats>(() {
  return StatsNotifier();
});

final editStatsUrlProvider = Provider<String>((ref) {
  final clientId = ref.watch(userIdProvider).valueOrNull ?? '';
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

class StatsNotifier extends AsyncNotifier<LocalAllStats> {
  static DateTime? _lastRefresh;
  static const _minRefreshInterval = Duration(seconds: 2);

  @override
  Future<LocalAllStats> build() async {
    dev.log('StatsNotifier: Building');
    return _fetchStats();
  }

  Future<LocalAllStats> _fetchStats() async {
    dev.log('StatsNotifier: Starting fetch');
    var statsManager = ref.read(statsManagerProvider);

    try {
      await statsManager.initialize();
      await statsManager.sync();

      return await statsManager.localAllStats;
    } catch (e, stackTrace) {
      dev.log('StatsNotifier: Error during fetch',
          error: e, stackTrace: stackTrace);

      rethrow;
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
    state = await AsyncValue.guard(() => _fetchStats());
    dev.log('StatsNotifier: Refresh completed');
  }
}
