import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/views/home/widgets/stats/streak_circle_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreakCircleController controller;

  setUp(() {
    controller = StreakCircleController(vsync: const TestVSync());
  });

  tearDown(() {
    controller.dispose();
  });

  group('StreakCircleController', () {
    test('initialises with animation controller', () {
      expect(controller.animationController, isNotNull);
      expect(
        controller.animationController.duration,
        const Duration(seconds: 3),
      );
      expect(controller.isAnimating, false);
    });

    test('updateAnimation starts animation when shouldAnimate is true', () {
      controller.updateAnimation(true);
      expect(controller.isAnimating, true);
      expect(controller.animationController.isAnimating, true);
    });

    test('updateAnimation stops animation when shouldAnimate is false', () {
      controller.updateAnimation(true);
      controller.updateAnimation(false);
      expect(controller.isAnimating, false);
      expect(controller.animationController.isAnimating, false);
    });

    test('isStreakDoneToday returns false for empty audio completed list', () {
      expect(controller.isStreakDoneToday(null), false);
      expect(controller.isStreakDoneToday([]), false);
    });

    test('isStreakDoneToday returns true for audio completed today', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final audioCompleted = [
        LocalAudioCompleted(timestamp: today.millisecondsSinceEpoch, id: '123'),
      ];

      expect(controller.isStreakDoneToday(audioCompleted), true);
    });

    test(
      'isStreakDoneToday returns false for audio completed before today',
      () {
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        final audioCompleted = [
          LocalAudioCompleted(
            timestamp: yesterday.millisecondsSinceEpoch,
            id: '123',
          ),
        ];

        expect(controller.isStreakDoneToday(audioCompleted), false);
      },
    );

    test('isStreakDoneToday uses provided now parameter', () {
      final customNow = DateTime(2024, 3, 15);
      final audioCompleted = [
        LocalAudioCompleted(
          timestamp: customNow.millisecondsSinceEpoch,
          id: '123',
        ),
      ];

      expect(
        controller.isStreakDoneToday(audioCompleted, now: customNow),
        true,
      );
    });

    group('Streak vs Consistency Score', () {
      test(
        'shouldShowConsistencyScore returns true when streak < 100 and consistency score exists',
        () {
          final stats = LocalAllStats.empty().copyWith(
            streakCurrent: 50,
            consistencyScore: 0.75,
          );
          expect(controller.shouldShowConsistencyScore(stats), true);
        },
      );

      test('shouldShowConsistencyScore returns false when streak >= 100', () {
        final stats = LocalAllStats.empty().copyWith(
          streakCurrent: 100,
          consistencyScore: 0.75,
        );
        expect(controller.shouldShowConsistencyScore(stats), false);
      });

      test('getDisplayValue returns percentage for consistency score', () {
        final stats = LocalAllStats.empty().copyWith(
          streakCurrent: 50,
          consistencyScore: 0.75,
        );
        expect('${controller.getDisplayValue(stats)}%', '75%');
      });

      test('getDisplayValue returns streak when above threshold', () {
        final stats = LocalAllStats.empty().copyWith(
          streakCurrent: 150,
          consistencyScore: 0.75,
        );
        expect('${controller.getDisplayValue(stats)}%', '150%');
      });

      test(
        'getProgressValue returns consistency score when below threshold',
        () {
          final stats = LocalAllStats.empty().copyWith(
            streakCurrent: 50,
            consistencyScore: 0.75,
          );
          expect(controller.getProgressValue(stats), 0.75);
        },
      );

      test('getProgressValue returns 0 when above threshold', () {
        final stats = LocalAllStats.empty().copyWith(
          streakCurrent: 150,
          consistencyScore: 0.75,
        );
        expect(controller.getProgressValue(stats), 0);
      });
    });
  });
}
