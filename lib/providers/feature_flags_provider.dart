import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Class to hold all feature flags
class FeatureFlags {
  final bool isStreakFreezeEnabled;

  const FeatureFlags({
    this.isStreakFreezeEnabled = true,
  });
}

/// Notifier for feature flags
class FeatureFlagsNotifier extends Notifier<FeatureFlags> {
  // These flags are configured at build time and cannot be changed at runtime
  static const bool _streakFreezeEnabled = false; // Default value

  @override
  FeatureFlags build() {
    return const FeatureFlags(
      isStreakFreezeEnabled: _streakFreezeEnabled,
    );
  }
}

/// Provider for feature flags
final featureFlagsProvider =
    NotifierProvider<FeatureFlagsNotifier, FeatureFlags>(
  FeatureFlagsNotifier.new,
);
