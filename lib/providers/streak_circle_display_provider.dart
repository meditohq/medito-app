import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';

enum StreakCircleDisplayType { consistencyScore, currentStreak }

class StreakCircleDisplayNotifier
    extends AsyncNotifier<StreakCircleDisplayType> {
  @override
  Future<StreakCircleDisplayType> build() async {
    var prefs = ref.watch(sharedPreferencesProvider);
    final value = prefs.getString(
      SharedPreferenceConstants.streakCircleDisplayPreference,
    );

    return value == StreakCircleDisplayType.currentStreak.name
        ? StreakCircleDisplayType.currentStreak
        : StreakCircleDisplayType.consistencyScore;
  }

  Future<void> setDisplayType(StreakCircleDisplayType type) async {
    var prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      SharedPreferenceConstants.streakCircleDisplayPreference,
      type.name,
    );
    state = AsyncValue.data(type);
  }
}

final streakCircleDisplayProvider =
    AsyncNotifierProvider<StreakCircleDisplayNotifier, StreakCircleDisplayType>(
      StreakCircleDisplayNotifier.new,
    );
