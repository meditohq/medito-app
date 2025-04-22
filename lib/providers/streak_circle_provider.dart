import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';

class StreakCircleNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    var prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(SharedPreferenceConstants.hasSeenStreakCircle) ??
        false;
  }

  Future<void> markAsSeen() async {
    var prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(SharedPreferenceConstants.hasSeenStreakCircle, true);
    state = const AsyncValue.data(true);
  }
}

final streakCircleProvider = AsyncNotifierProvider<StreakCircleNotifier, bool>(
  StreakCircleNotifier.new,
);
