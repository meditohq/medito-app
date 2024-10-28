import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:medito/constants/strings/string_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/utils/stats_manager.dart';

final statsProvider = FutureProvider<LocalAllStats>((ref) async {
  var statsManager = StatsManager();

  try {
    await statsManager.initialize();
    final stats = await statsManager.localAllStats;
    _updateiOSWidget(stats);
    return stats;
  } catch (e, stackTrace) {
    if (e is StateError) {
      return Future.error(
          'Failed to initialize StatsManager: ${e.message}', stackTrace);
    }

    return Future.error(StringConstants.statsLoadError, stackTrace);
  }
});

Future<void> _updateiOSWidget(LocalAllStats stats) async {
  if (Platform.isIOS) {
    await HomeWidget.saveWidgetData<String>(
        'streakTitle', "Current Streak");
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
