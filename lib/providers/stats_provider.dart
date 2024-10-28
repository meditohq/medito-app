import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:medito/constants/strings/string_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/utils/stats_manager.dart';

final statsManagerProvider = Provider<StatsManager>((ref) => StatsManager());

final statsProvider = AsyncNotifierProvider<StatsNotifier, LocalAllStats>(() {
  return StatsNotifier();
});

class StatsNotifier extends AsyncNotifier<LocalAllStats> {
  @override
  Future<LocalAllStats> build() async {
    return _fetchStats();
  }

  Future<LocalAllStats> _fetchStats() async {
    var statsManager = ref.read(statsManagerProvider);

    try {
      await statsManager.initialize();

      final stats = await statsManager.localAllStats;
      _updateiOSWidget(stats);
      return stats;
    } catch (e, stackTrace) {
      if (e is StateError) {
        throw AsyncError(
          'Failed to initialize StatsManager: ${e.message}',
          stackTrace,
        );
      }

      throw AsyncError(StringConstants.statsLoadError, stackTrace);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchStats());
  }
}

Future<void> _updateiOSWidget(LocalAllStats stats) async {
  if (Platform.isIOS) {
    await HomeWidget.saveWidgetData<String>('streakTitle', "Current Streak");
    await HomeWidget.saveWidgetData<String>(
        'streakValue', stats.streakCurrent.toString());
    await HomeWidget.saveWidgetData<List<int>>(
      'audioCompleted',
      stats.audioCompleted?.map((audio) => audio.timestamp).toList(),
    );
    HomeWidget.updateWidget(iOSName: 'StreakWidgetMedium');
    HomeWidget.updateWidget(iOSName: 'StreakWidgetSmall');
  }
}
