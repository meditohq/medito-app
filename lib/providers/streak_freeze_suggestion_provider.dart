import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/feature_flags_provider.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:medito/providers/stats_provider.dart';

// State class to hold streak freeze suggestion data
class StreakFreezeSuggestionState {
  final bool shouldShowSuggestion;
  final LocalAllStats? stats;
  final String lastSuggestionDate;

  const StreakFreezeSuggestionState({
    this.shouldShowSuggestion = false,
    this.stats,
    this.lastSuggestionDate = '',
  });

  StreakFreezeSuggestionState copyWith({
    bool? shouldShowSuggestion,
    LocalAllStats? stats,
    String? lastSuggestionDate,
  }) {
    return StreakFreezeSuggestionState(
      shouldShowSuggestion: shouldShowSuggestion ?? this.shouldShowSuggestion,
      stats: stats ?? this.stats,
      lastSuggestionDate: lastSuggestionDate ?? this.lastSuggestionDate,
    );
  }
}

// Provider for checking and managing streak freeze suggestions
final streakFreezeSuggestionProvider = NotifierProvider<
    StreakFreezeSuggestionNotifier, StreakFreezeSuggestionState>(() {
  return StreakFreezeSuggestionNotifier();
});

class StreakFreezeSuggestionNotifier
    extends Notifier<StreakFreezeSuggestionState> {
  @override
  StreakFreezeSuggestionState build() {
    // Initialize with empty state
    _initializeCheck();
    return const StreakFreezeSuggestionState();
  }

  Future<void> _initializeCheck() async {
    // Wait for the next frame to ensure the app is fully built
    await Future.delayed(Duration.zero);

    // Check for streak freeze suggestion after a short delay
    // This ensures all providers are properly initialized
    await Future.delayed(const Duration(milliseconds: 500));
    checkForStreakFreezeSuggestion();
  }

  Future<void> checkForStreakFreezeSuggestion() async {
    // Check if streak freeze feature is enabled
    final featureFlags = ref.read(featureFlagsProvider);
    if (!featureFlags.isStreakFreezeEnabled) {
      return;
    }

    // Check if user has active subscription
    final meData = await ref.read(meProvider.future);
    if (!meData.hasActiveSubscription) {
      return;
    }

    final statsManager = ref.read(statsManagerProvider);
    await statsManager.initialize();

    // Check if we've already shown a suggestion today
    if (_hasShownSuggestionToday()) {
      return;
    }

    final shouldSuggest = await statsManager.shouldSuggestStreakFreeze();
    if (shouldSuggest) {
      final stats = await statsManager.localAllStats;
      state = state.copyWith(
        shouldShowSuggestion: true,
        stats: stats,
      );
    }
  }

  bool _hasShownSuggestionToday() {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';

    return state.lastSuggestionDate == today;
  }

  void markSuggestionAsHandled() {
    // Save the current date as the last suggestion date
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';

    state = state.copyWith(
      shouldShowSuggestion: false,
      lastSuggestionDate: today,
    );
  }

  Future<void> useStreakFreeze() async {
    // Check if streak freeze feature is enabled
    final featureFlags = ref.read(featureFlagsProvider);
    if (!featureFlags.isStreakFreezeEnabled) {
      return;
    }

    final statsManager = ref.read(statsManagerProvider);
    await statsManager.initialize();

    final success = await statsManager.applyStreakFreeze();
    if (success) {
      // Refresh the stats provider
      ref.invalidate(statsProvider);
    }

    // Mark suggestion as handled
    markSuggestionAsHandled();
  }
}
