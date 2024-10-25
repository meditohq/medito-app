import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/string_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/utils/stats_manager.dart';

final statsProvider = FutureProvider<LocalAllStats>((ref) async {
  var statsManager = StatsManager();

  try {
    await statsManager.initialize();
    return await statsManager.localAllStats;
  } catch (e, stackTrace) {
    if (e is StateError) {
      return Future.error(
          'Failed to initialize StatsManager: ${e.message}', stackTrace);
    }

    return Future.error(StringConstants.statsLoadError, stackTrace);
  }
});
