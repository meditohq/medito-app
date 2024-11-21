import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/utils/stats_manager.dart';
import 'dart:developer' as dev;

import 'package:medito/views/settings/settings_screen.dart';

final statsManagerProvider = Provider<StatsManager>((ref) => StatsManager());

final statsProvider = AsyncNotifierProvider<StatsNotifier, LocalAllStats>(() {
  return StatsNotifier();
});

Future<void> updateiOSWidget(LocalAllStats stats) async {
  if (Platform.isIOS) {
    // await HomeWidget.saveWidgetData<String>(
    //     'streakValue', stats.streakCurrent.toString());
    await HomeWidget.saveWidgetData<String>(
        'streakValue',
        (stats.streakCurrent + (DateTime.now().millisecondsSinceEpoch % 100))
            .toString());
    await HomeWidget.saveWidgetData<List<int>>(
      'audioCompleted',
      stats.audioCompleted?.map((audio) => audio.timestamp).toList(),
    );
    await HomeWidget.saveWidgetData<String>(
      'dailyQuote',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
    await HomeWidget.saveWidgetData<bool>(
            'isMonthlyDonor', DateTime.now().millisecondsSinceEpoch % 2 == 0);
    await HomeWidget.updateWidget(iOSName: 'StreakWidgetMedium');
    await HomeWidget.updateWidget(iOSName: 'StreakWidgetSmall');
  }
}

Future<void> updateAndroidWidget(LocalAllStats stats) async {
  await HomeWidget.saveWidgetData<String>('streakValue', stats.streakCurrent.toString());
  await HomeWidget.saveWidgetData<String>(
    'timeListened', 
    (stats.totalTimeListened / 60000).round().toString()
  );
  await HomeWidget.saveWidgetData<String>(
    'tracksCompleted', 
    stats.totalTracksCompleted.toString()
  );

  await HomeWidget.updateWidget(
    androidName: 'StatsWidgetReceiver'
  );
}

Future<void> updateWidgets(LocalAllStats stats) async {
  if (Platform.isIOS) {
    await updateiOSWidget(stats);
  } else if (Platform.isAndroid) {
    await updateAndroidWidget(stats);
  }
}

final editStatsUrlProvider = Provider<String>((ref) {
  final clientId = ref.watch(userIdProvider).valueOrNull ?? '';
  final stats = ref.watch(statsProvider).valueOrNull;
  
  if (stats == null) return '$editStatsUrl?clientid=$clientId';
  
  final timeListened = (stats.totalTimeListened / 60000).round();
  
  return '$editStatsUrl?clientid=$clientId'
    '&streakcurrent=${stats.streakCurrent}'
    '&streaklongest=${stats.streakLongest}'
    '&trackscompleted=${stats.totalTracksCompleted}'
    '&timelistened=$timeListened';
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
      final stats = await statsManager.localAllStats;
      await updateWidgets(stats);
      return stats;
    } catch (e, stackTrace) {
      dev.log('StatsNotifier: Error during fetch', error: e, stackTrace: stackTrace);
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
    
    state = await AsyncValue.guard(() => _fetchStats());
    dev.log('StatsNotifier: Refresh completed');
  }
}
