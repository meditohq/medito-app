import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/views/home/widgets/stats/streak_circle.dart';
import 'package:medito/views/home/widgets/stats/streak_circle_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockStreakCircleController extends Mock
    implements StreakCircleController {}

class MockStatsNotifier extends Mock implements StatsNotifier {}

void main() {
  late MockStreakCircleController mockController;
  late MockStatsNotifier mockStatsNotifier;
  late LocalAllStats mockStats;

  setUp(() {
    mockController = MockStreakCircleController();
    mockStatsNotifier = MockStatsNotifier();
    mockStats = LocalAllStats.empty().copyWith(
      streakCurrent: 5,
      audioCompleted: [],
      updated: 1234567890,
    );

    when(() => mockController.animationController).thenReturn(
      AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 3),
      ),
    );
  });

  Widget buildTestWidget({VoidCallback? onTap}) {
    return ProviderScope(
      overrides: [
        statsProvider.overrideWith(() => mockStatsNotifier),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: StreakCircle(
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
  }

  group('StreakCircle Widget', () {
    testWidgets('shows loading state initially', (tester) async {
      when(() => mockStatsNotifier.state).thenReturn(
        const AsyncValue<LocalAllStats>.loading(),
      );

      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state when stats fetch fails', (tester) async {
      when(() => mockStatsNotifier.state).thenReturn(
        AsyncValue<LocalAllStats>.error('Error', StackTrace.empty),
      );

      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(HugeIcons.strokeRoundedHelpCircle), findsOneWidget);
    });

    testWidgets('shows streak count when stats are available', (tester) async {
      when(() => mockStatsNotifier.state).thenReturn(
        AsyncValue<LocalAllStats>.data(mockStats),
      );

      await tester.pumpWidget(buildTestWidget());

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapCount = 0;
      when(() => mockStatsNotifier.state).thenReturn(
        AsyncValue<LocalAllStats>.data(mockStats),
      );

      await tester.pumpWidget(
        buildTestWidget(onTap: () => tapCount++),
      );

      await tester.tap(find.byType(InkWell));
      expect(tapCount, 1);
    });
  });
}
