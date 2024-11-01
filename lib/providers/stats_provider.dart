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

Future<void> updateiOSWidget(LocalAllStats stats) async {
  if (Platform.isIOS) {
    // await HomeWidget.saveWidgetData<String>(
    //     'streakValue', stats.streakCurrent.toString());
        await HomeWidget.saveWidgetData<String>(
        'streakValue', (stats.streakCurrent + (DateTime.now().millisecondsSinceEpoch % 100)).toString());
    await HomeWidget.saveWidgetData<List<int>>(
      'audioCompleted',
      stats.audioCompleted?.map((audio) => audio.timestamp).toList(),
    );
    await HomeWidget.updateWidget(iOSName: 'StreakWidgetMedium');
    await HomeWidget.updateWidget(iOSName: 'StreakWidgetSmall');
  }
}

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
      await updateiOSWidget(stats);
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
    state = await AsyncValue.guard(() => _fetchStats());
  }
}
