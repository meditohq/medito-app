import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/day_boundary_offset_provider.dart';
import 'package:medito/widgets/calendar_stamp.dart';
import 'package:medito/views/home/widgets/bottom_sheet/stats/meditation_calendar_widget.dart';

class _DayOffset extends DayBoundaryOffsetNotifier {
  @override
  Future<int> build() async => 0;
}

void main() {
  test('impressions are stable for a date regardless of time or timezone', () {
    final first = CalendarStampImpression(DateTime(2026, 10, 12));
    final rebuilt = CalendarStampImpression(DateTime.utc(2026, 10, 12, 23));
    expect(rebuilt.offset, first.offset);
    expect(rebuilt.angle, first.angle);
    expect(rebuilt.seed, first.seed);
    final next = CalendarStampImpression(DateTime(2026, 10, 13));
    expect(next.offset, isNot(first.offset));
    expect(next.angle, isNot(first.angle));
    expect(first.offset.dx.abs(), lessThanOrEqualTo(2.5));
    expect(first.offset.dy.abs(), lessThanOrEqualTo(2));
  });

  test(
    'both calendars bucket session types identically and ignore freezes',
    () {
      LocalAudioCompleted session(String id, int day, int hour) =>
          LocalAudioCompleted(
            id: id,
            timestamp: DateTime(2026, 10, day, hour).millisecondsSinceEpoch,
          );
      final stamps = calendarStampsForSessions([
        session('guided', 14, 12),
        session('timer-600', 14, 2),
        session('manual1', 12, 12),
        session('streak-freeze', 11, 12),
        session('guided', 12, 14),
      ], const Duration(hours: 4));
      expect(stamps, {
        DateTime(2026, 10, 12): CalendarStampType.manual,
        DateTime(2026, 10, 13): CalendarStampType.timer,
        DateTime(2026, 10, 14): CalendarStampType.guided,
      });
    },
  );

  for (final reducedMotion in [false, true]) {
    testWidgets('new stamp reveals once, reduced motion: $reducedMotion', (
      tester,
    ) async {
      var completed = 0;
      Widget page() => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Center(
            child: CalendarStamp(
              date: DateTime(2026, 10, 30),
              type: CalendarStampType.timer,
              animateIn: true,
              onRevealComplete: () => completed++,
            ),
          ),
        ),
      );
      double opacity() => tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(CalendarStamp),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      await tester.pumpWidget(page());
      expect(opacity(), reducedMotion ? 1 : 0);
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      expect(completed, greaterThanOrEqualTo(1));
      final completions = completed;
      await tester.pumpWidget(page());
      expect(opacity(), 1);
      await tester.pumpAndSettle();
      expect(completed, completions);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('calendar keeps stamps on selection and fits $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final textScale = ValueNotifier<double>(1);
      addTearDown(textScale.dispose);
      final now = DateTime.now();
      final month = DateTime(now.year, now.month);
      final stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          for (var day = 1; day <= 20 && day < now.day; day++)
            LocalAudioCompleted(
              timestamp: month
                  .add(Duration(days: day - 1, hours: 12))
                  .millisecondsSinceEpoch,
              id: [
                'guided-track',
                'timer-600',
                'manual1',
                'streak-freeze',
              ][day % 4],
            ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dayBoundaryOffsetProvider.overrideWith(_DayOffset.new)],
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => ValueListenableBuilder<double>(
              valueListenable: textScale,
              builder: (context, scale, _) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: MeditationCalendarWidget(stats: stats),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (now.day > 1) {
        final stamp = find.byType(CalendarStamp).first;
        final date = tester.widget<CalendarStamp>(stamp).date;
        final transform = tester
            .widget<Transform>(
              find
                  .descendant(of: stamp, matching: find.byType(Transform))
                  .first,
            )
            .transform;
        await tester.tap(stamp);
        await tester.pumpAndSettle();
        final selectedStamp = find.byWidgetPredicate(
          (w) => w is CalendarStamp && w.date == date,
        );
        expect(selectedStamp, findsOneWidget);
        expect(
          tester
              .widget<Transform>(
                find
                    .descendant(
                      of: selectedStamp,
                      matching: find.byType(Transform),
                    )
                    .first,
              )
              .transform,
          transform,
        );
      }
      textScale.value = 2;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
