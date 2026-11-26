import 'dart:async';

import 'animated_end_screen_section.dart';

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
import '../../../widgets/snackbar_widget.dart';

import '../../../models/events/donation/donation_page_model.dart';
import '../../../models/local_all_stats.dart';
import '../../../models/stripe/payment_intent_model.dart';
import '../../../models/stripe/payment_method_model.dart' as payment_models;
import '../../../models/stripe/paywall_config_model.dart';
import '../../../providers/donation/donation_page_provider.dart';
import '../../../providers/donation/donation_snooze_provider.dart';
import '../../../providers/donation/end_screen_donation_experiment.dart';
import '../../../providers/donation/end_screen_milestone_experiment.dart';
import '../../../providers/stats_provider.dart';
import '../../../providers/stripe/payment_providers.dart';
import '../../../providers/stripe/payment_service_provider.dart';
import '../../../providers/stripe/payment_ui_controller.dart';
import '../../../repositories/auth/auth_repository.dart';
import '../../../routes/routes.dart';
import '../../../utils/logger.dart';
import '../../../utils/receipt_email.dart';
import '../../donation/receipt_email_prompt.dart';
import 'donation_thank_you_card.dart';
import 'end_screen_card.dart';
import 'feedback_widget.dart';
import 'inline_donation_pay.dart';

class DonationWidget extends ConsumerStatefulWidget {
  const DonationWidget({super.key, this.priorStats});

  /// Stats as they were before the session that just ended. Compared with
  /// the live stats to tell whether this session crossed a milestone (see
  /// [EndScreenMilestoneExperiment]). Null when there is no snapshot.
  final LocalAllStats? priorStats;

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

  // `end_screen_milestone_refresh` A/B. Control on a storage hiccup, so the
  // normal ask is what a failure degrades to.
  String _milestoneVariant = EndScreenMilestoneExperiment.variantControl;
  // The milestone this session crossed, in either arm. Tracks the live stats
  // until the impression is logged, then stays put for the visit so the card
  // on screen and the logged showing can never disagree.
  EndScreenMilestone? _milestone;
  bool get _showMilestoneCard =>
      _milestone != null &&
      _milestoneVariant == EndScreenMilestoneExperiment.variantRefresh;

  // The finished session reaches statsProvider a moment after the end screen
  // opens (see EndScreenMilestoneExperiment.statsCaughtUp; seen on the iOS
  // simulator, Nov 2026, where every milestone was missed). So the impression
  // — and in arm B the card itself — waits for it, up to the cap.
  Timer? _statsSettleTimer;
  bool _statsSettleCapElapsed = false;
  LocalAllStats? _liveStats;
  bool get _statsSettled {
    if (_statsSettleCapElapsed) return true;
    return EndScreenMilestoneExperiment.statsCaughtUp(
      prior: widget.priorStats,
      live: _liveStats,
    );
  }

  // An impression held back for the stats; sent on dispose if the user leaves
  // first, so the wait can never lose a showing.
  ({bool isSnoozed, bool? inlineRendered})? _heldImpression;
  // Mirrored from the snooze provider in build, for the dispose-time send.
  String _snoozeReason = '';
  late final _analytics = ref.read(analyticsServiceProvider);

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
  // Apple Pay looked available but a payment through it failed (not a
  // cancel): offer the card sheet for the rest of this visit, so the retry
  // is not the same dead end.
  bool _applePayFailed = false;

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
      _milestoneVariant = EndScreenMilestoneExperiment.resolveVariant(
        ref.read(sharedPreferencesProvider),
      );
    } catch (e) {
      AppLogger.w('DONATION', 'Could not resolve end-screen ask variant: $e');
    }
    _analytics; // Resolve now: ref is not usable in dispose.
    if (widget.priorStats != null) {
      _statsSettleTimer = Timer(
        EndScreenMilestoneExperiment.statsSettleCap,
        () {
          if (mounted) setState(() => _statsSettleCapElapsed = true);
        },
      );
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
    _statsSettleTimer?.cancel();
    final held = _heldImpression;
    if (!_impressionLogged && held != null) {
      unawaited(
        _analytics.logEvent(
          name: held.isSnoozed
              ? AnalyticsEventConstants.endScreenDonationCardSuppressed
              : AnalyticsEventConstants.endScreenDonationCardShown,
          parameters: _impressionParams(
            isSnoozed: held.isSnoozed,
            inlineRendered: held.inlineRendered,
          ),
        ),
      );
    }
    if (_milestone != null &&
        EndScreenMilestoneExperiment.activeMilestone == _milestone) {
      EndScreenMilestoneExperiment.activeMilestone = null;
    }
    super.dispose();
  }

  Map<String, Object> get _experimentParams => {
    AnalyticsEventConstants.paramVariantId: _variant,
    AnalyticsEventConstants.paramExperimentId:
        EndScreenDonationExperiment.experimentName,
    AnalyticsEventConstants.paramExperimentName:
        EndScreenDonationExperiment.experimentName,
    AnalyticsEventConstants.paramMilestoneRefresh: _milestoneVariant,
    if (_milestone != null) ...{
      AnalyticsEventConstants.paramMilestoneKind: _milestone!.kind,
      AnalyticsEventConstants.paramMilestoneValue: _milestone!.value,
    },
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
  static String _errorKind(Object err) => analyticsErrorKind(err);

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
    if (!_statsSettled) {
      // Build runs again when the stats arrive or the cap elapses.
      _heldImpression = (isSnoozed: isSnoozed, inlineRendered: inlineRendered);
      return;
    }
    _impressionLogged = true;
    _statsSettleTimer?.cancel();
    if (!isSnoozed && _milestone != null) {
      EndScreenMilestoneExperiment.activeMilestone = _milestone;
    }
    _logOnce(
      isSnoozed
          ? AnalyticsEventConstants.endScreenDonationCardSuppressed
          : AnalyticsEventConstants.endScreenDonationCardShown,
      parameters: _impressionParams(
        isSnoozed: isSnoozed,
        inlineRendered: inlineRendered,
      ),
    );
  }

  Map<String, Object> _impressionParams({
    required bool isSnoozed,
    bool? inlineRendered,
  }) => {
    AnalyticsEventConstants.paramPaywallSource:
        FirebaseAnalyticsService.paywallSourceEndScreen,
    if (isSnoozed) AnalyticsEventConstants.paramSnoozeReason: _snoozeReason,
    ..._experimentParams,
    if (inlineRendered != null)
      AnalyticsEventConstants.paramInlineRendered: inlineRendered.toString(),
  };

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
    // Apple Pay with no address on file: the sheet asks for it, and it is
    // confirmed (or asked for) once the payment has gone through.
    final emailFromSheet =
        method == payment_models.PaymentMethodType.applePay && email.isEmpty;
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
    PaymentResult? result;
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
      result = await ref
          .read(paymentUIControllerProvider.notifier)
          .initiateMonthlySubscription(
            context: context,
            amount: amount,
            currency: config.currencyCode,
            paymentMethod: method,
            paywallId: AnalyticsEventConstants.paywallIdEndScreenInline,
            userId: userId,
            userEmail: email.isEmpty ? null : email,
            paywallSource: FirebaseAnalyticsService.paywallSourceEndScreen,
            variantId: _variant,
            experimentId: EndScreenDonationExperiment.experimentName,
          );
    } finally {
      if (mounted) {
        final applePayFailed =
            method == payment_models.PaymentMethodType.applePay &&
            result is PaymentFailure;
        setState(() {
          _isProcessingInlinePayment = false;
          if (applePayFailed) _applePayFailed = true;
        });
      }
    }
    if (result is! PaymentSuccess || !mounted) return;
    const source = FirebaseAnalyticsService.paywallSourceEndScreen;
    if (emailFromSheet) {
      await ensureReceiptEmail(
        context,
        ref,
        logTag: 'DONATION',
        paywallSource: source,
      );
    } else {
      logDonationEmailOutcome('known', source);
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
    // Only sessions with a pre-session snapshot can cross a milestone, so the
    // stats are not watched (or loaded) for anything else.
    _snoozeReason = snoozeState.snoozeReason;
    if (!_impressionLogged && widget.priorStats != null) {
      _liveStats = ref.watch(statsProvider).value;
      _milestone = EndScreenMilestoneExperiment.milestoneCrossed(
        prior: widget.priorStats,
        current: _liveStats,
      );
    }

    // Feedback and locally stored donor/snooze state do not depend on the
    // remote donation copy. Keep them usable while that request is unavailable.
    if (donationPage.hasError &&
        !_loadFailureLogged &&
        !donationPage.retrying) {
      _loadFailureLogged = true;
      _logOnce(
        AnalyticsEventConstants.endScreenDonationCardLoadFailed,
        parameters: {
          AnalyticsEventConstants.paramPaywallSource:
              FirebaseAnalyticsService.paywallSourceEndScreen,
          AnalyticsEventConstants.paramErrorKind: _errorKind(
            donationPage.error!,
          ),
        },
      );
    }

    final page = donationPage.value;
    final showLocalState = snoozeState.isSnoozed;
    final canShowAsk = page != null || donationPage.hasError;
    if (showLocalState || (canShowAsk && !_isInlineVariant)) {
      _logImpression(isSnoozed: snoozeState.isSnoozed);
    }

    return Column(
      children: [
        AnimatedEndScreenSection(
          child: showLocalState && !snoozeState.isDonor
              ? const SizedBox.shrink()
              : showLocalState || canShowAsk
              ? Column(
                  children: [
                    showLocalState
                        ? const DonationThankYouCard()
                        : _MilestoneEntrance(
                            // Arm B only: control shows the card exactly as
                            // it always has.
                            ready:
                                _statsSettled ||
                                _milestoneVariant !=
                                    EndScreenMilestoneExperiment.variantRefresh,
                            enabled: _showMilestoneCard,
                            child: _buildDonationWidget(
                              context,
                              page ??
                                  const DonationPageModel(
                                    buttons: [ButtonModel()],
                                  ),
                              isSnoozed: false,
                            ),
                          ),
                    height20,
                  ],
                )
              : const SizedBox.shrink(),
        ),
        const FeedbackWidget(),
      ],
    );
  }

  Widget _buildDonationWidget(
    BuildContext context,
    DonationPageModel donationPageModel, {
    required bool isSnoozed,
  }) {
    // The backend's cardTextColor was tuned for the old purple card; the card
    // colour is theme-driven now, so the foreground must follow the theme too.
    final footerColor = context.onBrandAccent.withValues(alpha: 0.85);

    final l10n = AppLocalizations.of(context)!;
    final milestone = _showMilestoneCard ? _milestone : null;

    return EndScreenCard(
      inverted: true,
      title: milestone == null
          ? donationPageModel.title ?? l10n.supportMedito
          : milestone.kind == EndScreenMilestone.kindStreak
          ? l10n.endScreenMilestoneStreakTitle(milestone.value)
          : l10n.endScreenMilestoneSessionsTitle(milestone.value),
      body: milestone == null
          ? donationPageModel.text ?? l10n.meditoReliesOnYourDonationsToSurvive
          : l10n.endScreenMilestoneBody,
      corner: EndScreenCardCorner(
        icon: MeditoIcons.help,
        tooltip: AppLocalizations.of(context)!.donationInfo,
        onPressed: () => _showDonationInfoDialog(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _isInlineVariant
              ? _buildInlineOrFallback(donationPageModel, context)
              : _buildButtonRow(donationPageModel.buttons, context),
          // The inline card already carries title, body and the monthly
          // disclosure; the footer only restates the body below the pay button.
          if (!_isInlineVariant && donationPageModel.footerText != null)
            Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: Text(
                donationPageModel.footerText!,
                textAlign: TextAlign.center,
                style: EndScreenCard.secondaryStyle(
                  context,
                  color: footerColor,
                ),
              ),
            ),
        ],
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
      final applePayAvailable = Platform.isIOS && !_applePayFailed
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
    return SizedBox(
      height: 44,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            // Drawn on the brand-accent card: the theme's colours are for
            // the page, and its grey track read as a solid ring here.
            color: context.onBrandAccent,
            backgroundColor: Colors.transparent,
            semanticsLabel: AppLocalizations.of(context)!.loading,
          ),
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
                backgroundColor: context.onBrandAccent,
                foregroundColor: context.brandAccent,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(
                button.title ?? AppLocalizations.of(context)!.donateNow,
                style: EndScreenCard.buttonStyle(
                  context,
                  color: context.brandAccent,
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
                backgroundColor: context.onBrandAccent,
                foregroundColor: context.brandAccent,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(
                button.title ?? AppLocalizations.of(context)!.donateNow,
                style: EndScreenCard.buttonStyle(
                  context,
                  color: context.brandAccent,
                ),
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

/// Entrance for the milestone card (`end_screen_milestone_refresh`, arm B):
/// it holds back until the streak number above has finished its own change,
/// then fades and settles into place, so the two movements don't compete and
/// the card reads as a response to the number. Opacity and scale only — the
/// card keeps its space, so nothing below it shifts. With [enabled] false (or
/// reduced motion) the child is shown as is.
///
/// Until [ready] (the session's stats have caught up, so it is known whether
/// this is a milestone) the card is held invisible, so it never shows the
/// normal copy and then swaps.
class _MilestoneEntrance extends StatefulWidget {
  const _MilestoneEntrance({
    required this.ready,
    required this.enabled,
    required this.child,
  });

  final bool ready;
  final bool enabled;
  final Widget child;

  @override
  State<_MilestoneEntrance> createState() => _MilestoneEntranceState();
}

class _MilestoneEntranceState extends State<_MilestoneEntrance>
    with SingleTickerProviderStateMixin {
  // The end screen swaps the streak number 700ms in; its switcher then runs.
  static const _settleAt = Duration(milliseconds: 1200);
  final _mounted = Stopwatch()..start();

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Timer? _timer;
  // Decided once, as soon as the card is [ready]; it then stays decided, so
  // a card the user can already see is never hidden to replay an entrance.
  bool _decided = false;
  bool _armed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _decide();
  }

  @override
  void didUpdateWidget(_MilestoneEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    _decide();
  }

  void _decide() {
    if (_decided || !widget.ready) return;
    _decided = true;
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) return;
    _armed = true;
    final wait = _settleAt - _mounted.elapsed;
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_decided) {
      return Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: widget.child,
      );
    }
    if (!_armed) return widget.child;
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
        ),
        child: widget.child,
      ),
    );
  }
}
