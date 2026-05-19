import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stats_provider.dart';

/// User-configurable offset (in whole hours) that shifts when a new "day"
/// begins for streak calculation. Default `0` = midnight; e.g. `4` means a
/// session at 02:00 still counts toward the previous calendar day.
///
/// Persisted to `SharedPreferenceConstants.dayBoundaryOffsetHours` and pushed
/// into the StatsManager so streak math honours it on every recalculation.
class DayBoundaryOffsetNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final hours =
        prefs.getInt(SharedPreferenceConstants.dayBoundaryOffsetHours) ?? 0;
    // Mirror into StatsManager so freshly-built UI sees the right streak
    // even before any setter is called.
    ref.read(statsManagerProvider).setDayBoundaryOffset(Duration(hours: hours));
    return hours;
  }

  Future<void> setOffsetHours(int hours) async {
    await ref
        .read(statsManagerProvider)
        .setDayBoundaryOffset(Duration(hours: hours));
    state = AsyncValue.data(hours);
    // Recompute streaks against the new boundary.
    await ref.read(statsProvider.notifier).refreshFromLocal();
  }
}

final dayBoundaryOffsetProvider =
    AsyncNotifierProvider<DayBoundaryOffsetNotifier, int>(
  DayBoundaryOffsetNotifier.new,
);
