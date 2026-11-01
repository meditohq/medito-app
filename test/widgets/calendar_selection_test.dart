import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/theme/app_theme.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/day_boundary_offset_provider.dart';
import 'package:medito/views/home/widgets/bottom_sheet/stats/meditation_calendar_widget.dart';
import 'package:table_calendar/table_calendar.dart';

class _DayOffset extends DayBoundaryOffsetNotifier {
  @override
  Future<int> build() async => 0;
}

void main() {
  setUpAll(() async {
    for (final entry in {
      'Google Sans': 'assets/fonts/google-sans/GoogleSans-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  for (final themeMode in [ThemeMode.dark, ThemeMode.light]) {
    for (final reducedMotion in [false, true]) {
      testWidgets(
        'calendar selection animates and clears, reduced motion: $reducedMotion, theme: $themeMode',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final now = DateTime.now();
          final month = DateTime(now.year, now.month - 1);
          final capture = GlobalKey();
          final scrollController = ScrollController();
          addTearDown(scrollController.dispose);
          final semantics = tester.ensureSemantics();

          final stats = LocalAllStats.empty().copyWith(
            audioCompleted: [
              for (final day in [
                2,
                3,
                5,
                7,
                8,
                10,
                12,
                14,
                15,
                18,
                19,
                21,
                23,
                25,
                27,
                29,
              ])
                LocalAudioCompleted(
                  timestamp: DateTime(
                    month.year,
                    month.month,
                    day,
                    12,
                  ).millisecondsSinceEpoch,
                  id: day.isEven ? 'timer-600' : 'manual1',
                ),
            ],
          );
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: ProviderScope(
                overrides: [
                  dayBoundaryOffsetProvider.overrideWith(_DayOffset.new),
                ],
                child: Builder(
                  builder: (context) => MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: appTheme(context, themeMode),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        disableAnimations: reducedMotion,
                        textScaler: TextScaler.linear(
                          double.parse(
                            const String.fromEnvironment(
                              'CALENDAR_TEXT_SCALE',
                              defaultValue: '1',
                            ),
                          ),
                        ),
                      ),
                      child: child!,
                    ),
                    home: Scaffold(
                      appBar: AppBar(title: const Text('Meditation history')),
                      body: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        child: MeditationCalendarWidget(stats: stats),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final calendar = find.byType(TableCalendar<dynamic>);
          await tester.dragFrom(
            tester.getTopLeft(calendar) + const Offset(40, 200),
            const Offset(280, 0),
          );
          await tester.pumpAndSettle();

          Finder day(int day) => find.byKey(
            ValueKey(
              'calendar-day-${DateTime(month.year, month.month, day).toIso8601String()}',
            ),
          );
          double scale(int value) => tester
              .widget<ScaleTransition>(
                find
                    .descendant(
                      of: day(value),
                      matching: find.byType(ScaleTransition),
                    )
                    .first,
              )
              .scale
              .value;
          double opacity(int value) => tester
              .widget<FadeTransition>(
                find
                    .descendant(
                      of: day(value),
                      matching: find.byType(FadeTransition),
                    )
                    .first,
              )
              .opacity
              .value;
          Future<void> screenshot(String name) async {
            const output = String.fromEnvironment('CALENDAR_SCREENSHOTS');
            if (output.isEmpty || reducedMotion) return;
            await tester.runAsync(() async {
              final boundary =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(output).create(recursive: true);
              await File(
                '$output/$name-${themeMode.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          expect(scale(15), 1);
          expect(opacity(16), 1);
          await tester.tap(day(15));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));
          if (!reducedMotion) {
            expect(scale(15), inExclusiveRange(1, 1.08));
            expect(opacity(16), inExclusiveRange(0.65, 1));
          }
          await tester.pumpAndSettle();
          expect(scale(15), 1.08);
          expect(opacity(15), 1);
          expect(opacity(16), 0.65);
          expect(
            tester.getSemantics(day(15)).flagsCollection.isSelected,
            ui.Tristate.isTrue,
          );
          expect(
            tester
                .getSemantics(day(15))
                .getSemanticsData()
                .hasAction(ui.SemanticsAction.tap),
            isTrue,
          );
          expect(
            tester.getSemantics(day(16)).flagsCollection.isSelected,
            ui.Tristate.isFalse,
          );
          // Date text stays outside the fading stamp subtree.
          expect(
            find.ancestor(
              of: find.descendant(of: day(16), matching: find.byType(Text)),
              matching: find.byType(AnimatedOpacity),
            ),
            findsNothing,
          );
          await screenshot('calendar-selected');
          await tester.ensureVisible(find.byIcon(Icons.more_horiz).first);
          await tester.tap(find.byIcon(Icons.more_horiz).first);
          await tester.pumpAndSettle();
          expect(find.text('Open session'), findsNothing);
          expect(find.text('Edit date & time'), findsOneWidget);
          expect(find.text('Cancel'), findsNothing);
          await tester.tapAt(const Offset(10, 100));
          await tester.pumpAndSettle();

          scrollController.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(day(16));
          await tester.pumpAndSettle();
          expect(scale(15), 1);
          expect(opacity(15), 0.65);
          expect(scale(16), 1.08);
          expect(opacity(16), 1);

          scrollController.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(day(16));
          await tester.pumpAndSettle();
          expect(scale(16), 1);
          expect(opacity(15), 1);
          expect(opacity(16), 1);
          await screenshot('calendar-cleared');
          expect(
            tester.getSemantics(day(16)).flagsCollection.isSelected,
            ui.Tristate.isFalse,
          );
          scrollController.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(day(14));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byIcon(Icons.more_horiz).first);
          await tester.tap(find.byIcon(Icons.more_horiz).first);
          await tester.pumpAndSettle();
          expect(find.text('Open session'), findsOneWidget);
          expect(find.text('Edit date & time'), findsOneWidget);
          expect(find.text('Delete Session'), findsOneWidget);
          await screenshot('session-options');
          await tester.tap(find.text('Edit date & time'));
          await tester.pumpAndSettle();
          expect(find.text('Date'), findsOneWidget);
          expect(find.text('Time'), findsOneWidget);
          await screenshot('session-edit');
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byIcon(Icons.more_horiz).first);
          await tester.tap(find.byIcon(Icons.more_horiz).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete Session'));
          await tester.pumpAndSettle();
          expect(
            find.text(
              'Are you sure you want to delete this session? This will update your streak and stats.',
            ),
            findsOneWidget,
          );
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
