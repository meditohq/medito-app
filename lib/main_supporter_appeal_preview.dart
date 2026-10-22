/// Isolated, debug-only UI preview. Run with MOCK_MODE=true; no account, API
/// configuration or 30-day history is required. Uses the real card and screen.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/models/stripe/payment_config_model.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart';
import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/providers/donation/supporter_appeal_experiment.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/utils/currency.dart';
import 'package:medito/views/donation/supporter_donation_screen.dart';
import 'package:medito/views/home/widgets/announcement/supporter_appeal_card.dart';
import 'package:medito/views/previews/preview_support.dart';

void main() {
  if (!kDebugMode || !isMockMode) {
    throw StateError(
      'This preview requires a debug build with MOCK_MODE=true.',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SupporterAppealPreview());
}

const supporterPreviewConfig = PaywallConfigModel(
  currencyCode: 'eur',
  email: 'preview@example.com',
  pricing: PaymentPricing(
    oneTime: [],
    monthly: [300, 500, 1000, 1500],
    yearly: [3000, 5000, 10000, 15000],
    currency: 'eur',
    country: 'NL',
    suggested: SuggestedPricing(oneTime: 0, monthly: 500, yearly: 5000),
  ),
  experiment: PaywallExperiment(
    id: 'preview_ladder',
    variant: 'B',
    config: {
      'monthly': [300, 500, 1000, 1500],
      'yearly': [3000, 5000, 10000, 15000],
    },
  ),
);

/// Stops before any payment controller or SDK is invoked. A successful charge
/// is never reported, no donor suppression is written, and no API is called.
class PreviewPaymentUIController extends PaymentUIController {
  @override
  void build() {}

  PaymentResult _preview(
    BuildContext context,
    int amount,
    String currency,
    String frequency,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Preview: ${currencyAmountToUnitsString(amount, currency)} ${currency.toUpperCase()} $frequency. No payment was created.',
        ),
      ),
    );
    return const PaymentResult.cancelled();
  }

  @override
  Future<PaymentResult> initiateMonthlySubscription({
    required BuildContext context,
    required int amount,
    required String currency,
    required PaymentMethodType paymentMethod,
    String? paywallId,
    String? userId,
    String? userEmail,
    String? paywallSource,
    String? variantId,
    String? experimentId,
    VoidCallback? onSuccess,
    bool showSuccessFeedback = true,
    Map<String, String> campaignMetadata = const {},
  }) async => _preview(context, amount, currency, 'monthly');

  @override
  Future<PaymentResult> initiateYearlySubscription({
    required BuildContext context,
    required int amount,
    required String currency,
    required PaymentMethodType paymentMethod,
    String? paywallId,
    String? userId,
    String? userEmail,
    String? paywallSource,
    String? variantId,
    String? experimentId,
    VoidCallback? onSuccess,
    bool showSuccessFeedback = true,
    Map<String, String> campaignMetadata = const {},
  }) async => _preview(context, amount, currency, 'yearly');

  @override
  Future<PaymentResult> initiateOneTimePayment({
    required BuildContext context,
    required int amount,
    required String currency,
    required PaymentMethodType paymentMethod,
    String? paywallId,
    String? userId,
    String? userEmail,
    String? paywallSource,
    String? variantId,
    String? experimentId,
    VoidCallback? onSuccess,
    bool showSuccessFeedback = true,
    Map<String, String> campaignMetadata = const {},
  }) async => _preview(context, amount, currency, 'one-time');
}

class SupporterAppealPreview extends StatefulWidget {
  const SupporterAppealPreview({super.key});
  @override
  State<SupporterAppealPreview> createState() => _SupporterAppealPreviewState();
}

class _SupporterAppealPreviewState extends State<SupporterAppealPreview> {
  int _generation = 0;

  @override
  Widget build(BuildContext context) => Banner(
    message: 'PREVIEW',
    textDirection: TextDirection.ltr,
    layoutDirection: TextDirection.ltr,
    location: BannerLocation.topEnd,
    child: PreviewShell(
      key: ValueKey(_generation),
      themeMode: ThemeMode.dark,
      email: 'preview@example.com',
      prefs: {
        SupporterAppealExperiment.assignmentKey: jsonEncode({
          'arm': 'B',
          'at': DateTime.now().millisecondsSinceEpoch,
          'consistency': 'preview',
          'notifications_allowed': false,
          'nonce': '0000000000000001',
        }),
      },
      overrides: [
        supporterNativeCheckoutProvider.overrideWith(
          (ref) async => supporterPreviewConfig,
        ),
        supporterPaywallConfigProvider.overrideWith(
          (ref) async => supporterPreviewConfig,
        ),
        paymentUIControllerProvider.overrideWith(
          PreviewPaymentUIController.new,
        ),
        availablePaymentMethodsProvider.overrideWith(
          (ref) async => const [
            PaymentMethod(
              id: 'card',
              type: PaymentMethodType.card,
              displayName: 'Card',
              isAvailable: true,
            ),
          ],
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Supporter appeal preview'),
          actions: [
            IconButton(
              tooltip: 'Reset preview',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() => _generation++),
            ),
          ],
        ),
        body: ListView(
          children: const [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sample campaign and prices. Tap Donate now to try monthly/yearly. Checkout is simulated; no charge or notification is sent.',
              ),
            ),
            SupporterAppealCard(),
            Padding(
              padding: EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notification copy (visual preview)'),
                      SizedBox(height: 12),
                      Text(
                        SupporterAppealExperiment.notificationTitle,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(SupporterAppealExperiment.notificationBody),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
