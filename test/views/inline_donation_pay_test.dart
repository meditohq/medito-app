import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/theme/app_theme.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/stripe/payment_method_model.dart';
import 'package:medito/views/end_screen/widgets/inline_donation_pay.dart';

class _PayCall {
  _PayCall(this.amount, this.email, this.method);
  final int amount;
  final String email;
  final PaymentMethodType method;
}

void main() {
  Future<List<_PayCall>> pump(
    WidgetTester tester, {
    String currency = 'usd',
    List<int> ladder = const [300, 500, 1000, 2000],
    int? suggested = 1000,
    String? knownEmail,
    bool applePay = false,
    VoidCallback? onOtherAmount,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    final calls = <_PayCall>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            Theme(data: appTheme(context, themeMode), child: child!),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: InlineDonationPay(
              currencyCode: currency,
              ladder: ladder,
              suggestedAmount: suggested,
              knownEmail: knownEmail,
              applePayAvailable: applePay,
              isProcessing: false,
              onPay: (
                  {required amount, required email, required method}) async {
                calls.add(_PayCall(amount, email, method));
              },
              onOtherAmount: onOtherAmount ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return calls;
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('inline card text contrasts in ${mode.name} mode', (
      tester,
    ) async {
      await pump(tester, themeMode: mode);
      final context = tester.element(find.byType(InlineDonationPay));
      final background = context.brandPurple;
      final l10n = AppLocalizations.of(context)!;

      void expectReadable(String text, Color surface) {
        final label = tester.widget<Text>(find.text(text));
        final foreground = Color.alphaBlend(label.style!.color!, surface);
        final a = foreground.computeLuminance();
        final b = surface.computeLuminance();
        final ratio = ((a > b ? a : b) + 0.05) / ((a > b ? b : a) + 0.05);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$text in ${mode.name} mode',
        );
      }

      expect(find.byKey(inlineDonationEmailFieldKey), findsNothing);
      await tester.tap(find.byKey(inlineDonationPayButtonKey));
      await tester.pumpAndSettle();
      expectReadable(l10n.donationEmailHelper, background);
      expectReadable(l10n.donateMostPopular, background);
      expectReadable(l10n.donateMonthlyDisclosure, background);
      expectReadable(l10n.donateOtherAmount, background);
      expectReadable('\$3', background);
      expectReadable('\$10', context.onBrandPurple);

      final field = tester.widget<TextField>(
        find.byKey(inlineDonationEmailFieldKey),
      );
      expect(field.style!.color, Theme.of(context).colorScheme.onSurface);
      expect(field.decoration!.fillColor, Theme.of(context).cardColor);

      final button = tester.widget<ElevatedButton>(
        find.byKey(inlineDonationPayButtonKey),
      );
      expect(button.style!.backgroundColor!.resolve({}), context.onBrandPurple);
      expect(button.style!.foregroundColor!.resolve({}), background);

      await tester.tap(find.byKey(inlineDonationPayButtonKey));
      await tester.pumpAndSettle();
      expectReadable(l10n.donationEmailRequired, background);
      await tester.enterText(
        find.byKey(inlineDonationEmailFieldKey),
        'invalid',
      );
      await tester.tap(find.byKey(inlineDonationPayButtonKey));
      await tester.pumpAndSettle();
      expectReadable(l10n.donationEmailInvalid, background);
    });
  }

  testWidgets(
    'renders the localized ladder and preselects the suggested rung',
    (tester) async {
      await pump(tester);
      for (final label in ['\$3', '\$5', '\$10', '\$20']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Most popular'), findsOneWidget);
      // Button reflects the preselected \$10.
      expect(find.text('Donate \$10/month'), findsOneWidget);
    },
  );

  testWidgets('formats zero-decimal currencies without cents', (tester) async {
    await pump(
      tester,
      currency: 'jpy',
      ladder: const [500, 1000, 2000],
      suggested: 1000,
    );
    expect(find.text('¥1,000'), findsOneWidget);
    expect(find.text('Donate ¥1,000/month'), findsOneWidget);
  });

  testWidgets('tapping a chip changes the charged amount', (tester) async {
    final calls = await pump(tester, knownEmail: 'donor@example.com');
    await tester.tap(find.text('\$5'));
    await tester.pumpAndSettle();
    expect(find.text('Donate \$5/month'), findsOneWidget);

    await tester.tap(find.byKey(inlineDonationPayButtonKey));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(calls.single.amount, 500);
    expect(calls.single.email, 'donor@example.com');
    expect(calls.single.method, PaymentMethodType.card);
  });

  testWidgets('known email: no field, pays straight away', (tester) async {
    final calls = await pump(tester, knownEmail: 'donor@example.com');
    expect(find.byKey(inlineDonationEmailFieldKey), findsNothing);
    await tester.tap(find.byKey(inlineDonationPayButtonKey));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(calls.single.amount, 1000);
  });

  testWidgets('anonymous donor: asks for an email and blocks until valid', (
    tester,
  ) async {
    final calls = await pump(tester);
    expect(find.byKey(inlineDonationEmailFieldKey), findsNothing);
    await tester.tap(find.byKey(inlineDonationPayButtonKey));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(find.text('Continue to payment'), findsOneWidget);
    final field =
        tester.widget<TextField>(find.byKey(inlineDonationEmailFieldKey));
    expect(field.autofillHints, [AutofillHints.email]);
    expect(field.focusNode!.hasFocus, isTrue);
    expect(
        find.text('Enter your email so we can send a receipt.'), findsNothing);

    await tester.tap(find.byKey(inlineDonationPayButtonKey));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(
      find.text('Enter your email so we can send a receipt.'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(inlineDonationEmailFieldKey), 'nope');
    await tester.tap(find.byKey(inlineDonationPayButtonKey));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(
      find.text('That email address does not look right.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(inlineDonationEmailFieldKey),
      ' new@example.com ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(calls.single.email, 'new@example.com');
  });

  testWidgets('domain typo: confirms before paying, "Use this" fixes it', (
    tester,
  ) async {
    final calls = await pump(tester);
    await tester.tap(find.byKey(inlineDonationPayButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(inlineDonationEmailFieldKey),
      'donor@gmial.con',
    );
    await tester.tap(find.byKey(inlineDonationPayButtonKey));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(find.text('Check your email'), findsOneWidget);

    await tester.tap(find.text('Use this'));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));
    expect(calls.single.email, 'donor@gmail.com');
  });

  testWidgets('Apple Pay available: wallet button, applePay method', (
    tester,
  ) async {
    final calls = await pump(
      tester,
      knownEmail: 'donor@example.com',
      applePay: true,
    );
    expect(find.text('Donate with '), findsOneWidget);
    expect(find.textContaining('Pay · \$10'), findsOneWidget);
    await tester.tap(find.byKey(inlineDonationPayButtonKey));
    await tester.pumpAndSettle();
    expect(calls.single.method, PaymentMethodType.applePay);
  });

  testWidgets('anonymous Apple Pay donor supplies email before wallet opens',
      (tester) async {
    final calls = await pump(tester, applePay: true, knownEmail: '   ');
    expect(find.byKey(inlineDonationEmailFieldKey), findsNothing);
    await tester.tap(find.text('\$5'));
    await tester.tap(find.byKey(inlineDonationPayButtonKey));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(find.text('Continue to payment'), findsOneWidget);
    await tester.enterText(
        find.byKey(inlineDonationEmailFieldKey), 'wallet@example.com');
    await tester.tap(find.byKey(inlineDonationPayButtonKey));
    await tester.pumpAndSettle();
    expect(calls.single.email, 'wallet@example.com');
    expect(calls.single.amount, 500);
    expect(calls.single.method, PaymentMethodType.applePay);
  });

  testWidgets('"Other amount" hands off to the caller', (tester) async {
    var tapped = 0;
    await pump(tester, onOtherAmount: () => tapped++);
    await tester.tap(find.byKey(inlineDonationOtherAmountKey));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });
}
