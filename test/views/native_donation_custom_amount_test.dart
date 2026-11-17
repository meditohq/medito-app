// Regression cover for the custom-amount field's live amount echo.
//
// The 2607.20.x native page charged raw USD cents as the local currency, so
// variant-B donors were billed amounts that bore no relation to what the page
// showed. The echo exists so the resolved amount is visible on the page itself
// rather than first appearing in Apple/Google Pay's confirmation sheet.
//
// The axis that actually broke was minor-unit handling, so both a 2-decimal
// (USD) and a zero-decimal (JPY) currency are covered: typing the same digits
// must resolve to a different minor amount per currency.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medito/l10n/app_localizations.dart';

import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/models/stripe/payment_config_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/views/donation/native_donation_page.dart'
    show NativeDonationPage, customAmountFieldKey, donationPayButtonKey;

import '../helpers/firebase_analytics_test_helper.dart';

class _AnonymousAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Ladders are in minor units, so the same nominal tiers differ per currency:
/// 200 is $2.00 but ¥200.
PaywallConfigModel _config({
  required String currency,
  required List<int> monthly,
}) => PaywallConfigModel(
  currencyCode: currency,
  pricing: PaymentPricing(
    oneTime: monthly,
    monthly: monthly,
    yearly: monthly,
    currency: currency,
    country: currency == 'jpy' ? 'JP' : 'US',
    suggested: SuggestedPricing(
      oneTime: monthly.first,
      monthly: monthly.first,
      yearly: monthly.first,
    ),
  ),
);

void main() {
  setUp(FirebaseAnalyticsTestHelper.setupFirebaseAnalyticsMocks);

  Future<void> pump(
    WidgetTester tester,
    PaywallConfigModel config, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositorySyncProvider.overrideWithValue(
            _AnonymousAuthRepository(),
          ),
          // Card-only: keeps the Apple Pay branch out of the widget tree.
          availablePaymentMethodsProvider.overrideWith(
            (ref) async => const <PaymentMethod>[
              PaymentMethod(
                id: 'card',
                type: PaymentMethodType.card,
                displayName: 'Card',
                isAvailable: true,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NativeDonationPage(
              config: config,
              source: 'onboarding',
              onNext: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String digits) async {
    await tester.enterText(find.byKey(customAmountFieldKey), digits);
    await tester.pumpAndSettle();
  }

  testWidgets('echoes a 2-decimal currency in major units', (tester) async {
    await pump(tester, _config(currency: 'usd', monthly: [200, 500, 5000]));

    await type(tester, '25');

    // 25 major units -> 2500 minor. Not "$2,500", which is what reading the
    // typed digits as cents would have produced.
    expect(
      find.text(
        '\$25 a month — about \$0.83 a day to keep Medito free for millions.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('echoes a zero-decimal currency without dividing by 100', (
    tester,
  ) async {
    await pump(tester, _config(currency: 'jpy', monthly: [300, 500, 1000]));

    await type(tester, '1000');

    // JPY has no minor unit, so 1000 typed is ¥1,000 — not ¥10.
    expect(
      find.textContaining('¥1,000 a month — about ¥33 a day'),
      findsOneWidget,
    );
  });

  testWidgets('shows no echo below the minimum', (tester) async {
    await pump(tester, _config(currency: 'usd', monthly: [200, 500, 1000]));

    // $1 is under the $2 floor: the validation error owns the field instead.
    await type(tester, '1');

    expect(find.textContaining('a month'), findsNothing);
    expect(find.text('Minimum amount is \$2'), findsOneWidget);
  });

  testWidgets('disables Donate while no valid amount is chosen', (
    tester,
  ) async {
    await pump(tester, _config(currency: 'usd', monthly: [200, 500, 1000]));

    ElevatedButton donate() =>
        tester.widget<ElevatedButton>(find.byKey(donationPayButtonKey));
    expect(donate().onPressed, isNotNull);

    // Below the minimum: the tap used to do nothing, silently.
    await type(tester, '1');
    expect(donate().onPressed, isNull);

    await type(tester, '25');
    expect(donate().onPressed, isNotNull);
  });

  testWidgets('names amounts and the skip link for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, _config(currency: 'cad', monthly: [500, 1000, 2000]));

    // Shown as "$5", which would be read as US dollars.
    expect(find.text('\$5'), findsOneWidget);
    expect(find.bySemanticsLabel('CAD\u00a05, Most popular'), findsOneWidget);
    expect(find.bySemanticsLabel('CAD\u00a010'), findsOneWidget);
    await tester.ensureVisible(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Not now')),
      matchesSemantics(label: 'Not now', isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('drops the echo when the field is cleared', (tester) async {
    await pump(tester, _config(currency: 'usd', monthly: [200, 500, 1000]));

    await type(tester, '25');
    expect(find.textContaining('\$25 a month'), findsOneWidget);

    await type(tester, '');
    expect(find.textContaining('\$25 a month'), findsNothing);
  });

  testWidgets('thanks rather than divides above the largest preset', (
    tester,
  ) async {
    await pump(tester, _config(currency: 'usd', monthly: [200, 500, 1000]));

    // $100/month is ~$3.33 a day: no longer a trivial-sounding figure.
    await type(tester, '100');

    expect(find.textContaining('\$100 a month — thank you.'), findsOneWidget);
    expect(find.textContaining('a day'), findsNothing);
  });

  testWidgets('says what a preset costs before anything is typed', (
    tester,
  ) async {
    await pump(tester, _config(currency: 'usd', monthly: [200, 500, 1000]));

    // The suggested preset ($2) starts selected.
    expect(
      find.text(
        '\$2 a month — about \$0.07 a day to keep Medito free for millions.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('\$10'));
    await tester.pumpAndSettle();
    expect(find.textContaining('\$10 a month — about \$0.33'), findsOneWidget);
  });

  testWidgets('refreshed pricing resets stale amounts and custom input', (
    tester,
  ) async {
    await pump(tester, _config(currency: 'usd', monthly: [200, 5000]));
    await type(tester, '25');
    expect(find.text('Donate \$25/month'), findsOneWidget);

    // Keep the same mounted page while the asynchronous country/pricing
    // lookup replaces the configuration.
    await pump(tester, _config(currency: 'jpy', monthly: [300, 500, 1000]));
    expect(find.text('Donate ¥300/month'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(customAmountFieldKey))
          .controller!
          .text,
      isEmpty,
    );

    await pump(tester, _config(currency: 'jpy', monthly: [500, 1000]));
    expect(find.text('Donate ¥500/month'), findsOneWidget);
  });

  testWidgets('the full payment amount and cadence fit with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(
      tester,
      _config(currency: 'usd', monthly: [200, 5000]),
      textScale: 2,
    );
    await type(tester, '50000');
    final labelFinder = find.descendant(
      of: find.byKey(donationPayButtonKey),
      matching: find.text('Donate \$50,000/month'),
    );
    final label = tester.widget<Text>(labelFinder);
    final context = tester.element(labelFinder);
    final painter = TextPainter(
      text: TextSpan(
        text: label.data,
        style: DefaultTextStyle.of(context).style.merge(label.style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: tester.getSize(labelFinder).width);
    expect(
      tester.getSize(find.byKey(donationPayButtonKey)).height,
      greaterThanOrEqualTo(painter.height),
    );
    painter.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('puts the amount and cadence on the pay button', (tester) async {
    await pump(tester, _config(currency: 'usd', monthly: [200, 500, 1000]));

    Finder label(String text) => find.descendant(
      of: find.byKey(donationPayButtonKey),
      matching: find.text(text),
    );
    expect(label('Donate \$2/month'), findsOneWidget);

    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    expect(label('Donate \$2/year'), findsOneWidget);

    // Nothing valid chosen: disabled, and no amount to name.
    await type(tester, '1');
    expect(label('Donate'), findsOneWidget);
  });

  testWidgets(
    'tiny recurring amounts keep their cadence when equivalents round to zero',
    (tester) async {
      await pump(tester, _config(currency: 'jpy', monthly: [1, 10]));
      // Summary and pay button must both say this is a recurring commitment.
      expect(find.text('Donate ¥1/month'), findsNWidgets(2));
      expect(
        find.text('Your ¥1 helps keep Medito free for millions.'),
        findsNothing,
      );
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();
      expect(find.text('Donate ¥1/year'), findsNWidgets(2));
    },
  );
}
