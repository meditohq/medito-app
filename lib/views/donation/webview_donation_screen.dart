// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart'
    as payment_models;
import 'package:medito/providers/locale_provider.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app paywall hosted in a webview, loading the paywall site at
/// [paywallFormUrl] (env-specific — `paywall.*` for prod, `test.*` for
/// staging). The page renders all UI (amount /
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
  static const _loadTimeout = Duration(seconds: 15);
  static const _paywallId = 'paywall_webview';

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasLoadError = false;
  bool _isProcessingPayment = false;
  bool _didDonate = false;
  bool _presentedLogged = false;
  bool _dismissLogged = false;
  bool _loadOutcomeLogged = false;
  String _variantId = 'unknown';
  // Slug from the JS bridge `experiment_id` field, e.g. "donate3". Stable id
  // used for joins (matches Stripe metadata key).
  String _experimentId = 'unknown';
  // Captured at init/page-view so dispose() doesn't call ref.read after the
  // widget has been torn down (Riverpod throws, the analytics event is lost).
  String? _capturedUserId;
  Timer? _loadTimer;
  DateTime? _loadStartedAt;

  @override
  void initState() {
    super.initState();
    _capturedUserId = ref.read(authRepositorySyncProvider).currentUser?.id;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFAF8F5))
      ..addJavaScriptChannel(_channelName, onMessageReceived: _onChannelMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _loadTimer?.cancel();
            _logWebviewLoadFinished();
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasLoadError = false;
              });
            }
          },
          onWebResourceError: (error) {
            AppLogger.e(
              _logTag,
              'Web resource error: ${error.description} (main=${error.isForMainFrame})',
            );
            // Only fail closed for the main frame; subresource errors (icons,
            // analytics beacons, etc.) shouldn't tear down the whole paywall.
            if (error.isForMainFrame == true && _isLoading) {
              _logWebviewLoadFailed(
                'main_frame_error',
                detail: error.description,
              );
              _showLoadError();
            }
          },
        ),
      );
    _startLoad();
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    // Fallback in case the close paths didn't fire (e.g. parent route popped
    // us programmatically). Uses captured user id — see [_capturedUserId].
    if (!_didDonate) {
      _logPaywallDismissedNoPayment();
    }
    super.dispose();
  }

  void _logPaywallPresented() {
    if (_presentedLogged) return;
    _presentedLogged = true;
    try {
      // Anon sign-in may still be in flight at initState; refresh now that the
      // webview has loaded a page and a couple of seconds have passed.
      _capturedUserId ??= ref.read(authRepositorySyncProvider).currentUser?.id;
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.paywallPresented,
        parameters: {
          AnalyticsEventConstants.paramPaywallId: _paywallId,
          AnalyticsEventConstants.paramMeditoUserId:
              _capturedUserId ?? 'unknown',
          AnalyticsEventConstants.paramPaywallSource:
              widget.source ?? 'unknown',
          AnalyticsEventConstants.paramVariantId: _variantId,
          AnalyticsEventConstants.paramExperimentId: _experimentId,
        },
      );
    } catch (e) {
      AppLogger.w(_logTag, 'Failed to log paywall presented: $e');
    }
  }

  void _logPaywallDismissedNoPayment() {
    if (_dismissLogged) return;
    _dismissLogged = true;
    try {
      FirebaseAnalyticsService().logPaywallDismissedNoPayment(
        paywallId: _paywallId,
        userId: _capturedUserId,
        paywallSource: widget.source,
        variantId: _variantId,
        experimentId: _experimentId,
      );
    } catch (e) {
      AppLogger.w(_logTag, 'Failed to log paywall dismissal: $e');
    }
  }

  void _startLoad() {
    _loadTimer?.cancel();
    _loadOutcomeLogged = false;
    _loadStartedAt = DateTime.now();
    _logWebviewLoadStarted();
    setState(() {
      _isLoading = true;
      _hasLoadError = false;
    });
    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted || !_isLoading) return;
      AppLogger.w(
        _logTag,
        'Paywall load timed out after ${_loadTimeout.inSeconds}s',
      );
      _logWebviewLoadFailed('timeout');
      _showLoadError();
    });
    unawaited(_loadPaywall());
  }

  Map<String, Object> _baseLoadParams({int? durationMs}) {
    return <String, Object>{
      AnalyticsEventConstants.paramPaywallId: _paywallId,
      AnalyticsEventConstants.paramPaywallSource: widget.source ?? 'unknown',
      AnalyticsEventConstants.paramMeditoUserId: _capturedUserId ?? 'unknown',
      AnalyticsEventConstants.paramDurationMs: ?durationMs,
    };
  }

  void _logWebviewLoadStarted() {
    try {
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.paywallWebviewLoadStarted,
        parameters: _baseLoadParams(),
      );
    } catch (e) {
      AppLogger.w(_logTag, 'Failed to log webview load started: $e');
    }
  }

  void _logWebviewLoadFinished() {
    if (_loadOutcomeLogged) return;
    _loadOutcomeLogged = true;
    final duration = _loadStartedAt == null
        ? 0
        : DateTime.now().difference(_loadStartedAt!).inMilliseconds;
    try {
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.paywallWebviewLoadFinished,
        parameters: _baseLoadParams(durationMs: duration),
      );
    } catch (e) {
      AppLogger.w(_logTag, 'Failed to log webview load finished: $e');
    }
  }

  void _logWebviewLoadFailed(String reason, {String? detail}) {
    if (_loadOutcomeLogged) return;
    _loadOutcomeLogged = true;
    final duration = _loadStartedAt == null
        ? 0
        : DateTime.now().difference(_loadStartedAt!).inMilliseconds;
    final params = _baseLoadParams(durationMs: duration);
    params[AnalyticsEventConstants.paramReason] = reason;
    if (detail != null && detail.isNotEmpty) {
      // Truncated so we stay well under Firebase Analytics' 100-char param
      // value limit — short enough to fit alongside the other params too.
      params['detail'] = detail.length > 80 ? detail.substring(0, 80) : detail;
    }
    try {
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.paywallWebviewLoadFailed,
        parameters: params,
      );
    } catch (e) {
      AppLogger.w(_logTag, 'Failed to log webview load failed: $e');
    }
  }

  void _showLoadError() {
    _loadTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasLoadError = true;
    });
  }

  Future<void> _loadPaywall() async {
    final authRepository = ref.read(authRepositorySyncProvider);
    final email = authRepository.currentUser?.email;
    final userId = authRepository.currentUser?.id;
    final locale = ref.read(localeProvider)?.languageCode ?? 'en';

    final query = <String, String>{'locale': locale};
    final source = widget.source;
    if (source != null && source.isNotEmpty) query['source'] = source;
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

    final uri = Uri.parse(paywallFormUrl).replace(queryParameters: query);
    AppLogger.d(_logTag, 'Loading paywall: $uri');
    if (!mounted) return;
    try {
      await _controller.loadRequest(uri);
    } catch (e, st) {
      AppLogger.e(_logTag, 'loadRequest threw: $e\n$st');
      _showLoadError();
    }
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
      case 'log':
        final level = data['level'] as String? ?? 'info';
        final msg = data['message'] as String? ?? '';
        if (level == 'error') {
          AppLogger.e(_logTag, 'js: $msg');
        } else if (level == 'warn') {
          AppLogger.w(_logTag, 'js: $msg');
        } else {
          AppLogger.d(_logTag, 'js: $msg');
        }
      default:
        AppLogger.w(_logTag, 'Unknown message type: $type');
    }
  }

  void _handlePageView(Map<String, dynamic> data) {
    _variantId = (data['experiment_variant'] as String?) ?? 'unknown';
    final id = (data['experiment_id'] as String?)?.trim();
    if (id != null && id.isNotEmpty) _experimentId = id;
    AppLogger.d(
      _logTag,
      'page_view variant=$_variantId experiment_id=$_experimentId',
    );
    FirebaseAnalyticsService().logEvent(
      name: AnalyticsEventConstants.donationPageViewed,
      parameters: {
        AnalyticsEventConstants.paramVariantId: _variantId,
        AnalyticsEventConstants.paramPaywallSource: widget.source ?? 'unknown',
        AnalyticsEventConstants.paramExperimentId: _experimentId,
      },
    );
    _logPaywallPresented();
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
    _closePaywall();
  }

  /// Single exit path: log a dismiss (if applicable) then pop. Idempotent —
  /// [_logPaywallDismissedNoPayment] guards against double-firing, so
  /// [PopScope.onPopInvokedWithResult] firing after this is harmless.
  void _closePaywall() {
    if (!_didDonate) _logPaywallDismissedNoPayment();
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
    final idFromMessage = data['experiment_id'] as String?;
    if (idFromMessage != null && idFromMessage.isNotEmpty) {
      _experimentId = idFromMessage;
    }

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
    const paywallId = _paywallId;

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
          variantId: _variantId,
          experimentId: _experimentId,
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
          variantId: _variantId,
          experimentId: _experimentId,
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
          variantId: _variantId,
          experimentId: _experimentId,
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

  Widget _buildErrorOverlay() {
    final loc = AppLocalizations.of(context);
    final title = loc?.connectionErrorTitle ?? "Couldn't load paywall";
    final body =
        loc?.connectionErrorMessage ??
        'Please check your connection and try again.';
    final retry = loc?.tryAgainButton ?? 'Try again';
    final close = loc?.closeButton ?? 'Close';
    return Container(
      color: const Color(0xFFFAF8F5),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: Color(0xFF6C5CE7)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A17),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(fontSize: 14, color: Color(0xFFA8A49B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              minimumSize: const Size(200, 48),
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: _startLoad,
            child: Text(retry),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _closePaywall,
            child: Text(
              close,
              style: const TextStyle(color: Color(0xFFA8A49B)),
            ),
          ),
        ],
      ),
    );
  }

  void _notifyJsResult({required String status, String? message}) {
    if (!mounted) return;
    final payload = jsonEncode({'status': status, 'message': ?message});
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
    // Paywall page uses the warm-50 background — force dark status-bar icons
    // (and dark Android nav-bar icons) while this screen is on top, then let
    // the rest of the app revert to its own style after pop.
    const overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android
      statusBarBrightness: Brightness.light, // iOS
      systemNavigationBarColor: Color(0xFFFAF8F5),
      systemNavigationBarIconBrightness: Brightness.dark,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope<Object?>(
        // Logs a dismiss for system-driven pops (back gesture, hardware back,
        // parent route pop). [_closePaywall] is idempotent so app-driven exits
        // that already logged don't double-fire.
        onPopInvokedWithResult: (didPop, _) {
          if (didPop && !_didDonate) _logPaywallDismissedNoPayment();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFFAF8F5),
          body: SafeArea(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                // Flutter-rendered skeleton shown over the cream webview
                // background until onPageFinished fires. Fades out once the
                // real HTML is ready so users never see a blank screen.
                IgnorePointer(
                  ignoring: !_isLoading,
                  child: AnimatedOpacity(
                    opacity: _isLoading ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: const _PaywallSkeleton(),
                  ),
                ),
                if (_hasLoadError) _buildErrorOverlay(),
                if (isSmokeTestMode) _buildSmokeTestCloseButton(),
                // Close affordance lives in the webpage itself (delayed fade-in
                // so users don't dismiss before they've read the page). The JS
                // bridge posts a `close` message which _handleClose() pops.
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmokeTestCloseButton() {
    return Positioned(
      top: 8,
      right: 8,
      child: SafeArea(
        child: Semantics(
          label: 'Donation webview opened',
          button: true,
          child: IconButton.filledTonal(
            onPressed: _closePaywall,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.92),
              foregroundColor: const Color(0xFF1A1A17),
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.close, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Static Flutter-rendered preview of the paywall page shown while the
/// webview HTML is still loading. Mirrors the rough layout of paywall/index.astro
/// so the transition from skeleton → real page is smooth. Once the page is
/// rendered, this widget fades out and the webview's own in-page shimmer
/// (on the price ladder) takes over until config arrives.
class _PaywallSkeleton extends StatefulWidget {
  const _PaywallSkeleton();

  @override
  State<_PaywallSkeleton> createState() => _PaywallSkeletonState();
}

class _PaywallSkeletonState extends State<_PaywallSkeleton>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFFFAF8F5);
  static const _block = Color(0xFFF0ECE5);
  static const _blockHighlight = Color(0xFFE7E1D6);

  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  Widget _bar({required double width, required double height}) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, _) {
        final t = _shimmer.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(-0.4 + 2 * t, 0),
              colors: const [_block, _blockHighlight, _block],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              _bar(width: 140, height: 14),
              const SizedBox(height: 28),
              _bar(width: double.infinity, height: 32),
              const SizedBox(height: 12),
              _bar(width: 240, height: 32),
              const SizedBox(height: 24),
              _bar(width: 280, height: 12),
              const SizedBox(height: 8),
              _bar(width: 220, height: 12),
              const SizedBox(height: 32),
              _bar(width: double.infinity, height: 44),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _bar(width: 0, height: 52)),
                  const SizedBox(width: 12),
                  Expanded(child: _bar(width: 0, height: 52)),
                  const SizedBox(width: 12),
                  Expanded(child: _bar(width: 0, height: 52)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _bar(width: 0, height: 52)),
                  const SizedBox(width: 12),
                  Expanded(child: _bar(width: 0, height: 52)),
                  const SizedBox(width: 12),
                  Expanded(child: _bar(width: 0, height: 52)),
                ],
              ),
              const SizedBox(height: 24),
              _bar(width: double.infinity, height: 48),
              const SizedBox(height: 32),
              _bar(width: double.infinity, height: 56),
            ],
          ),
        ),
      ),
    );
  }
}
