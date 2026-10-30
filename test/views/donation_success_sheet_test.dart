import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/donation/donation_success_sheet.dart';

void main() {
  for (final currency in ['usd', 'jpy']) {
    testWidgets('confirmation persists and formats $currency correctly', (
      tester,
    ) async {
      var acknowledged = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await showDonationSuccessSheet(
                    context,
                    amount: 1000,
                    currency: currency,
                  );
                  acknowledged = true;
                },
                child: const Text('Donate'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Donate'));
      await tester.pumpAndSettle();
      expect(find.text('Thank You for Your Support'), findsOneWidget);
      expect(
        find.textContaining(currency == 'jpy' ? '1000 JPY' : '10.00 USD'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 10));
      expect(acknowledged, isFalse);
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(acknowledged, isTrue);
      expect(find.text('Thank You for Your Support'), findsNothing);
    });
  }

  testWidgets('confirmation fits large text on a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDonationSuccessSheet(
                context,
                amount: 500,
                currency: 'eur',
              ),
              child: const Text('Donate'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Donate'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
