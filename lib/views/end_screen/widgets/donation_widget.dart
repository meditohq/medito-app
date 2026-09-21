import 'dart:async';
import 'dart:io';

import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/providers.dart';
import '../../../services/analytics/firebase_analytics_service.dart';
import '../../../widgets/dialogs/dialogs.dart';
import '../../../widgets/medito_icon.dart';
import '../../../widgets/snackbar_widget.dart';

import '../../../models/events/donation/donation_page_model.dart';
import '../../../models/stripe/payment_method_model.dart' as payment_models;
import '../../../models/stripe/paywall_config_model.dart';
import '../../../providers/donation/donation_page_provider.dart';
import '../../../providers/donation/donation_snooze_provider.dart';
import '../../../providers/donation/end_screen_donation_experiment.dart';
import '../../../providers/stripe/payment_providers.dart';
import '../../../providers/stripe/payment_service_provider.dart';
import '../../../providers/stripe/payment_ui_controller.dart';
import '../../../repositories/auth/auth_repository.dart';
import '../../../routes/routes.dart';
import '../../../utils/logger.dart';
import '../../../utils/receipt_email.dart';
import '../../../widgets/errors/medito_error_widget.dart';
import '../../home/widgets/home_gradient_border.dart';
import 'donation_thank_you_card.dart';
import 'feedback_widget.dart';
import 'inline_donation_pay.dart';

class DonationWidget extends ConsumerStatefulWidget {
  const DonationWidget({super.key});

  @override
  ConsumerState<DonationWidget> createState() => DonationWidgetState();
}

class DonationWidgetState extends ConsumerState<DonationWidget>
    with WidgetsBindingObserver {
  // One impression latch per state object, i.e. per end-screen visit, so
  // rebuilds (snooze changes, feedback widget, theme) cannot double-count.
  // Mirrors the reminder card's latch in end_screen_view.dart.
  bool _impressionLogged = false;
  bool _loadFailureLogged = false;

  // `end_screen_inline_pay` A/B (see EndScreenDonationExperiment). Resolved
  // once per card visit; falls back to control if prefs are unavailable so a
  // storage hiccup can never blank the ask.
  String _variant = EndScreenDonationExperiment.variantControl;
  bool get _isInlineVariant =>
      _variant == EndScreenDonationExperiment.variantInline;

  // Variant B needs the localized end_screen ladder from /paywall. It is
  // usually warm (the player prefetches it), but if it is not here within
  // this cap the card degrades to the control CTA rather than holding the
  // ask hostage to a slow request — logged as inline_rendered=false.
  static const Duration _inlineConfigCap = Duration(seconds: 3);
  Timer? _inlineCapTimer;
  bool _inlineCapElapsed = false;
  // Once the card has shown the control CTA it stays on it for this visit —
  // a late config success must not swap the button under the user's thumb.
  bool _inlineFellBack = false;
  bool _isProcessingInlinePayment = false;

  // Recovery from a transient load failure. When a session ends with the
  // screen off, this widget mounts on the next app resume, and on Android the
  // radio is frequently not back yet, so the first request fails (~3.7% of
  // resume-time asks, Sep 2026). Riverpod already retries a failed provider
  // with backoff for ~40s; what was missing is a retry AFTER that budget is
  // spent — typically the user locked the phone again on the error card and
  // came back later — so we refetch on the next resume.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _variant = EndScreenDonationExperiment.resolveVariant(
        ref.read(sharedPreferencesProvider),
      );
    } catch (e) {
      AppLogger.w('DONATION', 'Could not resolve end-screen ask variant: $e');
    }
    if (_isInlineVariant) {
      _inlineCapTimer = Timer(_inlineConfigCap, () {
        if (mounted) setState(() => _inlineCapElapsed = true);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inlineCapTimer?.cancel();
    super.dispose();
  }

  Map<String, Object> get _experimentParams => {
    AnalyticsEventConstants.paramVariantId: _variant,
    AnalyticsEventConstants.paramExperimentId:
        EndScreenDonationExperiment.experimentName,
    AnalyticsEventConstants.paramExperimentName:
        EndScreenDonationExperiment.experimentName,
  };

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (ref.read(fetchDonationPageProvider).hasError) {
      _retryLoad();
    }
  }

  void _retryLoad() {
    if (!mounted) return;
    ref.invalidate(fetchDonationPageProvider);
  }

  /// Compact, low-cardinality label for the failure event so the next readout
  /// can tell "radio not up yet" from "server down".
  static String _errorKind(Object err) => switch (err) {
    NetworkConnectionError(:final kind) => 'network_${kind.name}',
    TimeoutError() => 'timeout',
    ServerError() => 'server',
    UnauthorizedError() || RefreshTokenError() => 'unauthorized',
    RateLimitError() => 'rate_limit',
    NotFoundError() => 'not_found',
    AppError() => 'app_error',
    _ => 'unknown',
  };

  void _logOnce(String event, {Map<String, Object>? parameters}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(name: event, parameters: parameters),
      );
    });
  }

  /// Fires the card's impression exactly once, tagged with which state the user
  /// actually saw. Deferred to a post-frame callback because it is called from
  /// build.
  void _logImpression({required bool isSnoozed, bool? inlineRendered}) {
    if (_impressionLogged) return;
    _impressionLogged = true;
    _logOnce(
      isSnoozed
          ? AnalyticsEventConstants.endScreenDonationCardSuppressed
          : AnalyticsEventConstants.endScreenDonationCardShown,
      parameters: {
        AnalyticsEventConstants.paramPaywallSource:
            FirebaseAnalyticsService.paywallSourceEndScreen,
        if (isSnoozed)
          AnalyticsEventConstants.paramSnoozeReason: ref
              .read(donationSnoozeProvider)
              .snoozeReason,
        ..._experimentParams,
        if (inlineRendered != null)
          AnalyticsEventConstants.paramInlineRendered: inlineRendered
              .toString(),
      },
    );
  }

  void _logDonateTap({
    required int buttonIndex,
    Map<String, Object> extra = const {},
  }) {
    // Taps only exist in the 'ask' state now (the thank-you card has no CTA
    // and snoozers see no card); card_state is kept for query continuity.
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.endScreenDonationCardDonateTap,
            parameters: {
              AnalyticsEventConstants.paramPaywallSource:
                  FirebaseAnalyticsService.paywallSourceEndScreen,
              AnalyticsEventConstants.paramButtonIndex: buttonIndex,
              AnalyticsEventConstants.paramCardState: 'ask',
              ..._experimentParams,
              ...extra,
            },
          ),
    );
  }

  /// Variant B: charge the selected monthly amount straight from the card.
  /// Same controller + metadata path as the onboarding native page, so the
  /// Stripe subscription carries experiment_name/variant/paywall_source and
  /// the donation_monthly event fires with our variant. Success flips the
  /// snooze state (recorded by the controller) and the card re-renders as the
  /// thank-you state on its own.
  Future<void> _payInline({
    required PaywallConfigModel config,
    required int amount,
    required String email,
    required payment_models.PaymentMethodType method,
  }) async {
    if (_isProcessingInlinePayment) return;
    // Remember the receipt address so the account prompt can prefill it.
    try {
      await ReceiptEmail.save(ref.read(sharedPreferencesProvider), email);
    } catch (e) {
      AppLogger.w('DONATION', 'Could not store receipt email: $e');
    }
    _logDonateTap(
      buttonIndex: 0,
      extra: {
        AnalyticsEventConstants.paramPaymentMethod: switch (method) {
          payment_models.PaymentMethodType.applePay => 'apple_pay',
          _ => 'card',
        },
        AnalyticsEventConstants.paramAmount: amount,
        AnalyticsEventConstants.paramDonationCurrency: config.currencyCode,
      },
    );
    setState(() => _isProcessingInlinePayment = true);
    try {
      // Stripe's publishable key / merchant id are applied when
      // paymentConfigProvider resolves (same preload the webview route does).
      // Usually already warm from the player; bounded so a slow request can't
      // hang the button.
      try {
        await ref
            .read(paymentConfigProvider.future)
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        AppLogger.w('DONATION', 'Payment config not ready for inline pay: $e');
      }
      if (!mounted) return;
      final userId = ref.read(authRepositorySyncProvider).currentUser?.id;
      await ref
          .read(paymentUIControllerProvider.notifier)
          .initiateMonthlySubscription(
            context: context,
            amount: amount,
            currency: config.currencyCode,
            paymentMethod: method,
            paywallId: AnalyticsEventConstants.paywallIdEndScreenInline,
            userId: userId,
            userEmail: email,
            paywallSource: FirebaseAnalyticsService.paywallSourceEndScreen,
            variantId: _variant,
            experimentId: EndScreenDonationExperiment.experimentName,
          );
    } finally {
      if (mounted) setState(() => _isProcessingInlinePayment = false);
    }
  }

  /// Variant B's "Other amount": the control path (webview), tagged so the
  /// readout can see how often B still needs the full page.
  void _openWebviewFromInline() {
    _logDonateTap(
      buttonIndex: 0,
      extra: {AnalyticsEventConstants.paramPaymentMethod: 'webview'},
    );
    handleNavigation(
      TypeConstants.route,
      [RouteConstants.donation],
      context,
      ref: ref,
      sourceRouteName: FirebaseAnalyticsService.paywallSourceEndScreen,
    );
  }

  String? _knownDonorEmail(PaywallConfigModel config) {
    final fromConfig = config.email?.trim();
    if (fromConfig != null && fromConfig.isNotEmpty) return fromConfig;
    try {
      final fromAuth = ref.read(authRepositorySyncProvider).getUserEmail();
      if (fromAuth != null && fromAuth.trim().isNotEmpty) {
        return fromAuth.trim();
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final donationPage = ref.watch(fetchDonationPageProvider);
    final snoozeState = ref.watch(donationSnoozeProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: donationPage.when(
        loading: () => _buildLoadingWidget(),
        error: (err, _) {
          // An impression that could never convert — counted separately so the
          // ask denominator stays honest instead of silently shrinking. Logged
          // only once Riverpod's own retries have given up, so a blip that
          // recovers on its own is not counted as a lost ask.
          if (!_loadFailureLogged && !donationPage.retrying) {
            _loadFailureLogged = true;
            _logOnce(
              AnalyticsEventConstants.endScreenDonationCardLoadFailed,
              parameters: {
                AnalyticsEventConstants.paramPaywallSource:
                    FirebaseAnalyticsService.paywallSourceEndScreen,
                AnalyticsEventConstants.paramErrorKind: _errorKind(err),
              },
            );
          }
          final error = err is AppError ? err : const UnknownError();
          return MeditoErrorWidget(
            error: error,
            onTap: _retryLoad,
            isScaffold: false,
          );
        },
        data: (DonationPageModel donationPageModel) {
          if (!snoozeState.isSnoozed && _isInlineVariant) {
            // Impression is logged from inside the B builder once it knows
            // whether the inline body or the fallback CTA rendered.
          } else {
            _logImpression(isSnoozed: snoozeState.isSnoozed);
          }
          // Someone who tapped "Hide for now" asked for silence: no card at
          // all for the snooze window (the suppressed impression above still
          // keeps the denominator honest). Donors get a thank-you instead.
          if (snoozeState.isSnoozed && !snoozeState.isDonor) {
            return const FeedbackWidget();
          }
          return Column(
            children: [
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 500),
                child: snoozeState.isSnoozed
                    ? const DonationThankYouCard()
                    : _buildDonationWidget(
                        context,
                        donationPageModel,
                        isSnoozed: false,
                      ),
              ),
              height20,
              const FeedbackWidget(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildDonationWidget(
    BuildContext context,
    DonationPageModel donationPageModel, {
    required bool isSnoozed,
  }) {
    // The backend's cardTextColor was tuned for the old purple card; the card
    // colour is theme-driven now, so the foreground must follow the theme too.
    final footerColor = context.onBrandPurple.withValues(alpha: 0.85);

    return HomeGradientBorder(
      backgroundColor: context.brandPurple,
      borderRadius: 14,
      borderWidth: 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      donationPageModel.title ?? 'Support Medito',
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontFamily: googleSans,
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                            color: context.onBrandPurple,
                          ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.donationInfo,
                  icon: MeditoIcon(
                    assetName: MeditoIcons.help,
                    size: 20,
                    color: context.onBrandPurple,
                  ),
                  onPressed: () => _showDonationInfoDialog(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              donationPageModel.text ??
                  AppLocalizations.of(
                    context,
                  )!.meditoReliesOnYourDonationsToSurvive,
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: context.onBrandPurple.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _isInlineVariant
                  ? _buildInlineOrFallback(donationPageModel, context)
                  : _buildButtonRow(donationPageModel.buttons, context),
            ),
            if (donationPageModel.footerText != null)
              Padding(
                padding: const EdgeInsets.only(top: 14.0, right: 8),
                child: Text(
                  donationPageModel.footerText!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: footerColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Variant B body. Renders the inline chips + pay button when the
  /// end_screen paywall config is here and offers a monthly ladder; otherwise
  /// (error, or still loading past the cap) the control CTA, so the user is
  /// never left with an empty card. The impression is logged at that decision
  /// with `inline_rendered` so the two B experiences separate in the readout.
  Widget _buildInlineOrFallback(
    DonationPageModel donationPageModel,
    BuildContext context,
  ) {
    final configAsync = ref.watch(endScreenPaywallConfigProvider);
    const source = FirebaseAnalyticsService.paywallSourceEndScreen;

    final config = configAsync.value;
    final ladder = config?.effectiveLadder('monthly', source: source);
    final canRenderInline =
        config != null &&
        ladder != null &&
        ladder.isNotEmpty &&
        config.isFrequencyOffered('monthly', source: source);

    if (canRenderInline && !_inlineFellBack) {
      _inlineCapTimer?.cancel();
      _logImpression(isSnoozed: false, inlineRendered: true);
      final applePayAvailable = Platform.isIOS
          ? (ref.watch(applePayAvailableProvider).value ?? false)
          : false;
      return InlineDonationPay(
        currencyCode: config.currencyCode,
        ladder: ladder,
        suggestedAmount: config.effectiveSuggested('monthly', source: source),
        knownEmail: _knownDonorEmail(config),
        applePayAvailable: applePayAvailable,
        isProcessing: _isProcessingInlinePayment,
        onPay: ({required amount, required email, required method}) =>
            _payInline(
              config: config,
              amount: amount,
              email: email,
              method: method,
            ),
        onOtherAmount: _openWebviewFromInline,
      );
    }

    final gaveUp =
        configAsync.hasError || (configAsync.hasValue && !canRenderInline);
    if (gaveUp || _inlineCapElapsed || _inlineFellBack) {
      _inlineFellBack = true;
      _logImpression(isSnoozed: false, inlineRendered: false);
      return _buildButtonRow(donationPageModel.buttons, context);
    }

    // Still within the cap: hold the CTA slot at the fallback's height.
    return const SizedBox(
      height: 44,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Future<void> _showDonationInfoDialog(BuildContext context) async {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.endScreenDonationCardInfoOpened,
            parameters: {
              AnalyticsEventConstants.paramPaywallSource:
                  FirebaseAnalyticsService.paywallSourceEndScreen,
            },
          ),
    );
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return MeditoDialog(
          title: AppLocalizations.of(context)!.donationInfoTitle,
          content: SingleChildScrollView(
            child: MeditoDialogBody(
              AppLocalizations.of(context)!.donationInfoMessage,
            ),
          ),
          actions: [
            MeditoDialogSecondaryButton(
              label: AppLocalizations.of(context)!.cancel,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            MeditoDialogPrimaryButton(
              label: AppLocalizations.of(context)!.hideForNow,
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _snoozeDonationAsk(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _snoozeDonationAsk(BuildContext context) async {
    try {
      await ref.read(donationSnoozeProvider.notifier).snoozeForDays(30);
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: AnalyticsEventConstants.endScreenDonationCardSnoozed,
              parameters: {
                AnalyticsEventConstants.paramPaywallSource:
                    FirebaseAnalyticsService.paywallSourceEndScreen,
                AnalyticsEventConstants.paramDurationMs: const Duration(
                  days: 30,
                ).inMilliseconds,
              },
            ),
      );
      if (context.mounted) {
        showSnackBar(
          context,
          AppLocalizations.of(context)!.donationAskHiddenMessage,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, AppLocalizations.of(context)!.anErrorOccurred);
      }
    }
  }

  Widget _buildButtonRow(List<ButtonModel>? buttons, BuildContext context) {
    if (buttons == null || buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Widget> buttonWidgets = [];

    if (buttons.length == 1) {
      ButtonModel button = buttons[0];

      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                _logDonateTap(buttonIndex: 0);
                handleNavigation(
                  TypeConstants.route,
                  [RouteConstants.donation],
                  context,
                  ref: ref,
                  sourceRouteName:
                      FirebaseAnalyticsService.paywallSourceEndScreen,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.onBrandPurple,
                foregroundColor: context.brandPurple,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(
                button.title ?? AppLocalizations.of(context)!.donateNow,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.brandPurple,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      for (int i = 0; i < buttons.length; i++) {
        ButtonModel button = buttons[i];

        buttonWidgets.add(
          Expanded(
            child: ElevatedButton(
              // `ref` is required: handleDonationNavigation bails out and
              // returns false when it is null, so omitting it here made every
              // CTA in the multi-button layout a no-op.
              onPressed: () {
                _logDonateTap(buttonIndex: i);
                handleNavigation(
                  TypeConstants.route,
                  [RouteConstants.donation],
                  context,
                  ref: ref,
                  sourceRouteName:
                      FirebaseAnalyticsService.paywallSourceEndScreen,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.onBrandPurple,
                foregroundColor: context.brandPurple,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(
                button.title ?? AppLocalizations.of(context)!.donateNow,
              ),
            ),
          ),
        );

        if (i < buttons.length - 1) {
          buttonWidgets.add(const SizedBox(width: 8));
        }
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: buttonWidgets,
      );
    }
  }
}
