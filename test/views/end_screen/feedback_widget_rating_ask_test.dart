import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/views/end_screen/widgets/feedback_widget.dart';
import 'package:medito/views/previews/preview_support.dart';

void main() {
  for (final mood in ['😊', '😐', '☹️']) {
    testWidgets('$mood thanks the user without requesting a rating', (
      tester,
    ) async {
      await tester.pumpWidget(
        const PreviewShell(
          prefs: {
            'review_happy_feedback_days': ['2026-01-01', '2026-01-02'],
          },
          locale: Locale('en'),
          padded: true,
          child: FeedbackWidget(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(mood));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('Thanks for sharing'), findsOneWidget);
      expect(find.text('Rate Medito'), findsNothing);
      expect(find.text('Could you leave Medito a rating?'), findsNothing);
    });
  }
}
