import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shared_preference/shared_preference_provider.dart';

class DurationPreferenceNotifier extends Notifier<int?> {
  static const _durationPreferenceKey = 'meditation_duration_preference';

  @override
  int? build() {
    final sharedPreferences = ref.watch(sharedPreferencesProvider);
    return sharedPreferences.getInt(_durationPreferenceKey);
  }

  void setDuration(int? duration) {
    if (duration != null) {
      state = duration;

      final sharedPreferences = ref.read(sharedPreferencesProvider);
      sharedPreferences.setInt(_durationPreferenceKey, duration);
    }
  }
}

final durationPreferenceProvider =
    NotifierProvider<DurationPreferenceNotifier, int?>(
  DurationPreferenceNotifier.new,
);
