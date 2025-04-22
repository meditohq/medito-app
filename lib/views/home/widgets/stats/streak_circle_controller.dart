import 'package:flutter/material.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/local_all_stats.dart';

class StreakCircleController extends ChangeNotifier {
  final TickerProvider vsync;
  late final AnimationController animationController;
  bool _isAnimating = false;

  static const _streakThreshold = 100;

  StreakCircleController({required this.vsync}) {
    animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(seconds: 3),
    );
  }

  bool get isAnimating => _isAnimating;

  bool shouldShowConsistencyScore(LocalAllStats stats) {
    return stats.streakCurrent < _streakThreshold &&
        stats.consistencyScore != null;
  }

  String getDisplayValue(LocalAllStats stats) {
    if (shouldShowConsistencyScore(stats)) {
      return '${(stats.consistencyScore! * 100).round()}';
    }
    return '${stats.streakCurrent}';
  }

  double getProgressValue(LocalAllStats stats) {
    if (shouldShowConsistencyScore(stats)) {
      return stats.consistencyScore ?? 0;
    }
    return 0; // No progress circle needed for streak
  }

  void updateAnimation(bool shouldAnimate) {
    if (shouldAnimate && !_isAnimating) {
      animationController.repeat();
      _isAnimating = true;
    } else if (!shouldAnimate && _isAnimating) {
      animationController.stop();
      _isAnimating = false;
    }
  }

  bool isStreakDoneToday(List<LocalAudioCompleted>? audioCompleted,
      {DateTime? now}) {
    if (audioCompleted == null || audioCompleted.isEmpty) {
      return false;
    }

    final currentDate = now ?? DateTime.now();
    final today =
        DateTime(currentDate.year, currentDate.month, currentDate.day);

    return audioCompleted.any((audio) {
      final audioDate = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
      return audioDate.isAtSameMomentAs(today) || audioDate.isAfter(today);
    });
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }
}
