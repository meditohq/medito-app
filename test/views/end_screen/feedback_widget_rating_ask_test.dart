import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:medito/views/end_screen/widgets/feedback_widget.dart';
import 'package:medito/views/previews/preview_support.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';

void main() {
  // Two earlier happy days: today's 😊 is the third.
  final eligible = <String, Object>{
    'review_happy_feedback_days': ['2026-01-01', '2026-01-02'],
  };

  Future<void> pump(
    WidgetTester tester,
    Map<String, Object> prefs, {
    bool suppress = false,
  }) async {
    await tester.pumpWidget(
      PreviewShell(
        prefs: prefs,
        locale: const Locale('en'),
        padded: true,
        child: FeedbackWidget(suppressRatingAsk: () => suppress),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapHappy(WidgetTester tester) async {
    await tester.tap(find.text('😊'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('third happy day shows the ask; Not now closes it for good', (
    tester,
  ) async {
    await pump(tester, eligible);
    await tapHappy(tester);

    expect(find.text('Could you leave Medito a rating?'), findsOneWidget);
    expect(find.text('Rate Medito'), findsOneWidget);

    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(find.text('Could you leave Medito a rating?'), findsNothing);
    expect(find.textContaining('Thanks for sharing'), findsOneWidget);

    final prefs = ProviderScope.containerOf(
      tester.element(find.byType(FeedbackWidget)),
    ).read(sharedPreferencesProvider);
    expect(prefs.getBool('review_prompt_shown'), isTrue);
  });

  testWidgets('not shown before the third happy day', (tester) async {
    await pump(tester, const {});
    await tapHappy(tester);
    expect(find.text('Could you leave Medito a rating?'), findsNothing);

    final prefs = ProviderScope.containerOf(
      tester.element(find.byType(FeedbackWidget)),
    ).read(sharedPreferencesProvider);
    expect(prefs.getStringList('review_happy_feedback_days'), [
      DateFormat('yyyy-MM-dd').format(DateTime.now()),
    ]);
  });

  testWidgets('not shown after a donate tap on the same screen', (
    tester,
  ) async {
    await pump(tester, eligible, suppress: true);
    await tapHappy(tester);
    expect(find.text('Could you leave Medito a rating?'), findsNothing);
  });

  testWidgets('neutral face never shows the ask', (tester) async {
    await pump(tester, eligible);
    await tester.tap(find.text('😐'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Could you leave Medito a rating?'), findsNothing);
  });
}
