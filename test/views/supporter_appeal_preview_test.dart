import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/main_supporter_appeal_preview.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/views/donation/supporter_donation_screen.dart';
import 'package:medito/views/home/widgets/announcement/supporter_appeal_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'preview card opens real yearly panel and simulated checkout; dismissal resets',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentServiceProvider.overrideWith(
              (ref) =>
                  throw StateError('Preview must not fetch real payment data'),
            ),
          ],
          child: const SupporterAppealPreview(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Donate now'));
      await tester.pumpAndSettle();
      expect(find.byType(SupporterDonationScreen), findsOneWidget);
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();
      final donate = find.widgetWithText(ElevatedButton, 'Donate');
      await tester.ensureVisible(donate);
      await tester.tap(donate);
      await tester.pumpAndSettle();
      expect(
        find.text('Preview: 50.00 EUR yearly. No payment was created.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(CloseButton),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(SupporterAppealCard)).height, 0);
      await tester.tap(find.byTooltip('Reset preview'));
      await tester.pumpAndSettle();
      expect(find.text('Donate now'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
