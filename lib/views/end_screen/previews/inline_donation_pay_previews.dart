// Widget previews for variant B of the end-screen donation card
// (`end_screen_inline_pay`): the inline amount chips + pay button.
//
//   flutter widget-preview start --web-server
//
// InlineDonationPay is pure presentation, so it previews without Stripe or
// Riverpod. It is wrapped in the same brand-purple card chrome the real
// DonationWidget draws around it. Axes: wallet vs card button, known vs
// unknown email, currency width (USD / BRL / JPY / INR), theme, locale and
// large text.

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/models/stripe/payment_method_model.dart';
import 'package:medito/views/end_screen/widgets/donation_thank_you_card.dart';
import 'package:medito/views/end_screen/widgets/inline_donation_pay.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/views/previews/preview_support.dart';

Future<void> _noopPay({
  required int amount,
  required String email,
  required PaymentMethodType method,
}) async {}

void _noop() {}

/// The real card's chrome (title, body, then the CTA slot) so the inline body
/// is judged in context, not floating on a page.
class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Scaffold like the real end screen: gives the theme's page background
    // and the Material ancestor Text needs (else yellow debug underlines).
    // Top-aligned + shrink-wrapped like the real end screen's scroll view;
    // a bare Scaffold body would stretch the card to the full phone height.
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HomeGradientBorder(
              backgroundColor: context.brandPurple,
              borderRadius: 14,
              borderWidth: 0.5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Support Medito',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontFamily: sourceSerif,
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                            color: context.onBrandPurple,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Medito is free because people like you choose to support '
                      'it. No ads, no paywalls.',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                            color: context.onBrandPurple.withValues(alpha: 0.9),
                          ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _inline({
  String currency = 'usd',
  List<int> ladder = const [300, 500, 1000, 2000],
  int? suggested = 1000,
  String? knownEmail = 'donor@example.com',
  bool applePay = false,
  bool processing = false,
}) => _CardFrame(
  child: InlineDonationPay(
    currencyCode: currency,
    ladder: ladder,
    suggestedAmount: suggested,
    knownEmail: knownEmail,
    applePayAvailable: applePay,
    isProcessing: processing,
    onPay: _noopPay,
    onOtherAmount: _noop,
  ),
);

Widget wrapDark(Widget child) => PreviewShell(prefs: prefsDark, child: child);

Widget wrapLight(Widget child) =>
    PreviewShell(prefs: prefsLight, themeMode: ThemeMode.light, child: child);

Widget wrapEs(Widget child) =>
    PreviewShell(prefs: prefsDark, locale: const Locale('es'), child: child);

@Preview(
  group: 'Inline donation pay',
  name: 'iOS · Apple Pay · known email · dark',
  size: phoneSize,
  wrapper: wrapDark,
)
Widget inlineApplePayDark() => _inline(applePay: true);

@Preview(
  group: 'Inline donation pay',
  name: 'Android · card button · known email · dark',
  size: phoneSize,
  wrapper: wrapDark,
)
Widget inlineCardDark() => _inline();

@Preview(
  group: 'Inline donation pay',
  name: 'Anonymous · email field · dark',
  size: phoneSize,
  wrapper: wrapDark,
)
Widget inlineAnonymousDark() => _inline(knownEmail: null);

@Preview(
  group: 'Inline donation pay',
  name: 'Anonymous · Apple Pay · light',
  size: phoneSize,
  wrapper: wrapLight,
)
Widget inlineAnonymousLight() => _inline(knownEmail: null, applePay: true);

@Preview(
  group: 'Inline donation pay',
  name: 'BRL · wide amounts · Apple Pay',
  size: phoneSize,
  wrapper: wrapDark,
)
Widget inlineBrl() => _inline(
  currency: 'brl',
  ladder: const [1500, 2500, 5000, 10000],
  suggested: 5000,
  applePay: true,
);

@Preview(
  group: 'Inline donation pay',
  name: 'JPY · zero-decimal',
  size: phoneSize,
  wrapper: wrapDark,
)
Widget inlineJpy() => _inline(
  currency: 'jpy',
  ladder: const [500, 1000, 2000, 5000],
  suggested: 1000,
);

@Preview(
  group: 'Inline donation pay',
  name: 'INR · Apple Pay · large text 1.4×',
  size: phoneSize,
  textScaleFactor: 1.4,
  wrapper: wrapDark,
)
Widget inlineInrLargeText() => _inline(
  currency: 'inr',
  ladder: const [10000, 20000, 40000, 80000],
  suggested: 20000,
  applePay: true,
);

@Preview(
  group: 'Inline donation pay',
  name: 'Spanish · anonymous · dark',
  size: phoneSize,
  wrapper: wrapEs,
)
Widget inlineEs() => _inline(knownEmail: null);

@Preview(
  group: 'Inline donation pay',
  name: 'Processing state',
  size: phoneSize,
  wrapper: wrapDark,
)
Widget inlineProcessing() => _inline(processing: true, applePay: true);

// ---------------------------------------------------------------------------
// Donor thank-you state (no CTA). "Hide for now" snoozers see no card at all,
// so there is nothing to preview for them.

Widget _thankYou() => const Scaffold(
  body: SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: DonationThankYouCard(),
      ),
    ),
  ),
);

@Preview(
  group: 'Donation thank-you',
  name: 'Donor · dark',
  size: phoneSize,
  wrapper: wrapDark,
)
Widget thankYouDark() => _thankYou();

@Preview(
  group: 'Donation thank-you',
  name: 'Donor · light',
  size: phoneSize,
  wrapper: wrapLight,
)
Widget thankYouLight() => _thankYou();

@Preview(
  group: 'Donation thank-you',
  name: 'Donor · Spanish',
  size: phoneSize,
  wrapper: wrapEs,
)
Widget thankYouEs() => _thankYou();

@Preview(
  group: 'Donation thank-you',
  name: 'Donor · large text 1.4×',
  size: phoneSize,
  textScaleFactor: 1.4,
  wrapper: wrapDark,
)
Widget thankYouLargeText() => _thankYou();
