import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/providers.dart';

/// Class to hold all feature flags
class FeatureFlags {
  final bool isStreakFreezeEnabled;

  const FeatureFlags({
    this.isStreakFreezeEnabled = false,
  });

  FeatureFlags copyWith({
    bool? isStreakFreezeEnabled,
  }) {
    return FeatureFlags(
      isStreakFreezeEnabled:
          isStreakFreezeEnabled ?? this.isStreakFreezeEnabled,
    );
  }
}

/// Notifier for feature flags
class FeatureFlagsNotifier extends Notifier<FeatureFlags> {
  static const String _streakFreezeKey = 'streak_freeze_enabled';

  @override
  FeatureFlags build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final isStreakFreezeEnabled =
        prefs.getBool(_streakFreezeKey) ?? false; // Default to disabled

    return FeatureFlags(
      isStreakFreezeEnabled: isStreakFreezeEnabled,
    );
  }

  /// Toggle the streak freeze feature on/off
  Future<void> toggleStreakFreeze(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_streakFreezeKey, enabled);

    // Update the state
    state = state.copyWith(isStreakFreezeEnabled: enabled);
  }
}

/// Provider for feature flags
final featureFlagsProvider =
    NotifierProvider<FeatureFlagsNotifier, FeatureFlags>(
  FeatureFlagsNotifier.new,
);
