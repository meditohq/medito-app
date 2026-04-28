// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/config_constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart' as payment_models;
import 'package:medito/providers/locale_provider.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app paywall hosted in a webview, loading the paywall site at
/// [ConfigConstants.paywallFormUrl]. The page renders all UI (amount /
/// frequency / success / close button); Flutter just bridges the JS channel
/// to the native Stripe sheet.
class WebViewDonationScreen extends ConsumerStatefulWidget {
  const WebViewDonationScreen({super.key, this.source});

  final String? source;

  @override
  ConsumerState<WebViewDonationScreen> createState() =>
      _WebViewDonationScreenState();
}

class _WebViewDonationScreenState extends ConsumerState<WebViewDonationScreen> {
  static const _logTag = 'WEBVIEW_DONATION';
  static const _channelName = 'MeditoPaywall';

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  bool _didDonate = false;
  String _variantId = 'control';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFAF8F5))
      ..addJavaScriptChannel(_channelName, onMessageReceived: _onChannelMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            AppLogger.e(_logTag, 'Web resource error: ${error.description}');
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );
    unawaited(_loadPaywall());
  }

  Future<void> _loadPaywall() async {
    final authRepository = ref.read(authRepositorySyncProvider);
    final email = authRepository.currentUser?.email;
    final userId = authRepository.currentUser?.id;
    final locale = ref.read(localeProvider)?.languageCode ?? 'en';

    final query = <String, String>{'locale': locale};
    if (email != null && email.isNotEmpty) query['email'] = email;
    if (userId != null && userId.isNotEmpty) query['user_id'] = userId;

    try {
      final config = await ref.read(paymentConfigProvider.future);
      query['currency'] = config.pricing.currency;
      query['country'] = config.pricing.country;
    } catch (e) {
      AppLogger.w(_logTag, 'Could not load payment config: $e');
    }

    try {
      final methods = await ref.read(availablePaymentMethodsProvider.future);
      query['isInAppPaymentAvailable'] = methods.isNotEmpty ? 'true' : 'false';
    } catch (e) {
      AppLogger.w(_logTag, 'Could not load payment methods: $e');
      query['isInAppPaymentAvailable'] = 'false';
    }

    if (kDebugMode) query['debug'] = 'true';

    final uri = Uri.parse(
      ConfigConstants.paywallFormUrl,
    ).replace(queryParameters: query);
    AppLogger.d(_logTag, 'Loading paywall: $uri');
    if (mounted) await _controller.loadRequest(uri);
  }

  void _onChannelMessage(JavaScriptMessage message) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.e(_logTag, 'Bad JS payload: ${message.message} ($e)');
      return;
    }

    final type = data['type'] as String? ?? '';
    switch (type) {
      case 'paywall_payment_request':
        _handlePaymentRequest(data);
      case 'page_view':
        _handlePageView(data);
      case 'close':
        _handleClose();
      case 'open_url':
        _handleOpenUrl(data);
      default:
        AppLogger.w(_logTag, 'Unknown message type: $type');
    }
  }

  void _handlePageView(Map<String, dynamic> data) {
    _variantId = (data['experiment_variant'] as String?) ?? 'control';
    final experimentId = data['experiment_id'] as String? ?? '';
    AppLogger.d(_logTag, 'page_view variant=$_variantId experiment=$experimentId');
    FirebaseAnalyticsService().logEvent(
      name: AnalyticsEventConstants.donationPageViewed,
      parameters: {
        AnalyticsEventConstants.paramVariantId: _variantId,
        AnalyticsEventConstants.paramPaywallSource: widget.source ?? 'unknown',
      },
    );
  }

  Future<void> _handleOpenUrl(Map<String, dynamic> data) async {
    final url = data['url'] as String? ?? '';
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      AppLogger.w(_logTag, 'open_url: invalid uri $url');
      return;
    }
    AppLogger.d(_logTag, 'open_url -> $uri');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _handleClose() {
    AppLogger.d(_logTag, 'close requested by webpage');
    if (mounted) Navigator.of(context).pop(_didDonate);
  }

  Future<void> _handlePaymentRequest(Map<String, dynamic> data) async {
    if (_isProcessingPayment) {
      AppLogger.d(_logTag, 'payment already in progress, ignoring duplicate');
      return;
    }

    final amount = (data['amount'] as num?)?.toInt();
    final frequency = data['frequency'] as String? ?? 'one_time';
    final email = data['email'] as String?;
    final variantFromMessage = data['experiment_variant'] as String?;
    if (variantFromMessage != null) _variantId = variantFromMessage;

    if (amount == null || amount <= 0) {
      AppLogger.w(_logTag, 'invalid amount in payment request: $amount');
      _notifyJsResult(status: 'error', message: 'Invalid amount');
      return;
    }

    _isProcessingPayment = true;
    try {
      await _runStripeFlow(
        amount: amount,
        frequency: frequency,
        emailFromPage: email,
      );
    } finally {
      _isProcessingPayment = false;
    }
  }

  Future<void> _runStripeFlow({
    required int amount,
    required String frequency,
    String? emailFromPage,
  }) async {
    final uiController = ref.read(paymentUIControllerProvider.notifier);
    final authRepository = ref.read(authRepositorySyncProvider);
    final userId = authRepository.currentUser?.id ?? 'unknown';
    final userEmail = (emailFromPage != null && emailFromPage.isNotEmpty)
        ? emailFromPage
        : authRepository.currentUser?.email;

    final paymentConfig = await ref.read(paymentConfigProvider.future);
    final availableMethods = await ref.read(
      availablePaymentMethodsProvider.future,
    );

    if (availableMethods.isEmpty) {
      AppLogger.w(_logTag, 'no native payment methods available');
      _notifyJsResult(
        status: 'error',
        message: 'No payment methods available on this device.',
      );
      return;
    }

    // Prefer Apple Pay on iOS, Google Pay on Android, else card.
    var selectedMethod = availableMethods.first;
    for (final method in availableMethods) {
      if (method.type == payment_models.PaymentMethodType.applePay ||
          method.type == payment_models.PaymentMethodType.googlePay) {
        selectedMethod = method;
        break;
      }
    }

    final currency = paymentConfig.pricing.currency;
    const paywallId = 'paywall_webview';

    PaymentResult result;
    switch (frequency) {
      case 'monthly':
        result = await uiController.initiateMonthlySubscription(
          context: context,
          amount: amount,
          currency: currency,
          paymentMethod: selectedMethod.type,
          paywallId: paywallId,
          userId: userId,
          userEmail: userEmail,
          paywallSource: widget.source,
          onSuccess: () {},
        );
      case 'yearly':
        result = await uiController.initiateYearlySubscription(
          context: context,
          amount: amount,
          currency: currency,
          paymentMethod: selectedMethod.type,
          paywallId: paywallId,
          userId: userId,
          userEmail: userEmail,
          paywallSource: widget.source,
          onSuccess: () {},
        );
      case 'one_time':
      default:
        result = await uiController.initiateOneTimePayment(
          context: context,
          amount: amount,
          currency: currency,
          paymentMethod: selectedMethod.type,
          paywallId: paywallId,
          userId: userId,
          userEmail: userEmail,
          paywallSource: widget.source,
          onSuccess: () {},
        );
    }

    switch (result) {
      case PaymentSuccess():
        _didDonate = true;
        _notifyJsResult(status: 'success');
      case PaymentFailure(:final errorMessage):
        _notifyJsResult(status: 'error', message: errorMessage);
      case PaymentCancelled():
        _notifyJsResult(status: 'cancelled');
    }
  }

  void _notifyJsResult({required String status, String? message}) {
    if (!mounted) return;
    final payload = jsonEncode({
      'status': status,
      'message': ?message,
    });
    // Don't await — the JS handler is fire-and-forget.
    unawaited(
      _controller
          .runJavaScript('window.meditoOnPaymentResult($payload);')
          .catchError((Object e) {
        AppLogger.w(_logTag, 'runJavaScript failed: $e');
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_didDonate);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF8F5),
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
