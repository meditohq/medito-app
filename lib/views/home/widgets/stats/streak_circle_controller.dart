import 'package:flutter/material.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/streak_circle_display_provider.dart';
import 'package:medito/views/home/widgets/stats/streak_circle_constants.dart';

class StreakCircleController extends ChangeNotifier {
  final TickerProvider vsync;
  late final AnimationController animationController;
  bool _isAnimating = false;

  static const _streakThreshold = 100;

  StreakCircleController({required this.vsync}) {
    animationController = AnimationController(
      vsync: vsync,
      duration: StreakCircleConstants.animationDuration,
    );
  }

  bool get isAnimating => _isAnimating;

  /// Mirrors the platform's reduced-motion setting
  /// (`MediaQuery.disableAnimations`, which Android raises when its animator
  /// scale is 0). While set, [updateAnimation] never starts the ring: the
  /// travelling glow repaints a blurred sweep every frame for as long as Home
  /// is on screen, which is exactly the kind of decoration reduced motion asks
  /// us to drop, and on a software-rendered emulator it was enough to take the
  /// whole emulator process down (CI upgrade test, 2026-09-15).
  bool reduceMotion = false;

  bool shouldShowConsistencyScore(
    LocalAllStats stats, [
    StreakCircleDisplayType? displayType,
  ]) {
    // If display preference is explicitly set to currentStreak, always show streak
    if (displayType == StreakCircleDisplayType.currentStreak) {
      return false;
    }

    // If display preference is set to consistencyScore or not specified,
    // use the threshold logic to determine what to show
    return stats.streakCurrent < _streakThreshold;
  }

  String getDisplayValue(
    LocalAllStats stats, [
    StreakCircleDisplayType? displayType,
  ]) {
    if (shouldShowConsistencyScore(stats, displayType)) {
      return '${(stats.consistencyScore * 100).round()}';
    }
    return '${stats.streakCurrent}';
  }

  double getProgressValue(
    LocalAllStats stats, [
    StreakCircleDisplayType? displayType,
  ]) {
    if (shouldShowConsistencyScore(stats, displayType)) {
      return stats.consistencyScore;
    }
    return 0; // No progress circle needed for streak
  }

  void updateAnimation(bool shouldAnimate) {
    if (reduceMotion) shouldAnimate = false;
    if (shouldAnimate && !_isAnimating) {
      animationController.repeat();
      _isAnimating = true;
    } else if (!shouldAnimate && _isAnimating) {
      animationController.stop();
      _isAnimating = false;
    }
  }

  bool isStreakDoneToday(
    List<LocalAudioCompleted>? audioCompleted, {
    DateTime? now,
  }) {
    if (audioCompleted == null || audioCompleted.isEmpty) {
      return false;
    }

    var currentDate = now ?? DateTime.now();
    var today = DateTime(currentDate.year, currentDate.month, currentDate.day);

    return audioCompleted.any((audio) {
      var audioDate = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
      var audioDateOnly = DateTime(
        audioDate.year,
        audioDate.month,
        audioDate.day,
      );
      return audioDateOnly == today;
    });
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }
}
