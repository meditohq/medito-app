import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/widgets/inputs/medito_text_field.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/stripe/payment_method_model.dart'
    as payment_models;
import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/models/stripe/payment_error_model.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/views/donation/receipt_email_prompt.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:medito/utils/currency.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/receipt_email.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/buttons/apple_pay_donate_button.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/inputs/email_typo_hint.dart';
import 'package:medito/constants/theme/medito_text.dart';

enum _Frequency {
  oneTime('oneTime', 'one_time'),
  monthly('monthly', 'monthly'),
  yearly('yearly', 'yearly');

  const _Frequency(this.configKey, this.analyticsKey);

  final String configKey;
  final String analyticsKey;

  String label(AppLocalizations l10n) => switch (this) {
    oneTime => l10n.singleDonation,
    monthly => l10n.monthlyDonation,
    yearly => l10n.yearlyDonation,
  };
}

// Stable handles for the page's two text inputs. Both fields render
// unconditionally, so a bare find.byType(TextField) is ambiguous in tests —
// target these instead.
@visibleForTesting
const donationEmailFieldKey = Key('donation_email_field');
@visibleForTesting
const customAmountFieldKey = Key('donation_custom_amount_field');
const donationPayButtonKey = Key('donation_pay_button');

// Native fallback copy mirrors the paywall webview page (which is
// English-only; localized copy arrives via the experiment config).
const _defaultHeading = 'Keep meditation free\nfor the next million';
const _defaultSubcopy =
    '4.1 million people meditate with Medito for free. '
    'No ads, no paywalls — funded entirely by donors like you.';
// Registration line in the small print under the pay buttons.
const _registrationCopy =
    'Stichting Medito · Non-profit registered in the Netherlands · KvK 75284251';

/// Native rendering of the server-resolved donation configuration. The caller
/// provides a page or pager shell, loads [config], and handles load failures.
class NativeDonationPage extends ConsumerStatefulWidget {
  const NativeDonationPage({
    super.key,
    required this.config,
    required this.onNext,
    required this.source,
    this.campaignMetadata = const {},
    this.showCloseButton = true,
    this.closeButtonDelay = Duration.zero,
    this.showNotNow = true,
    this.closeButtonOnRight = false,
    this.onNativeUnavailable,
  });

  final PaywallConfigModel config;
  final VoidCallback onNext;
  final String source;
  final Map<String, String> campaignMetadata;

  /// Disable when the enclosing screen supplies its own header close button.
  final bool showCloseButton;

  /// Fades the close button in after this delay, matching the paywall
  /// webview (which reveals its × after 5s). Skipped for screen-reader users,
  /// who get the button straight away. Back navigation is never delayed.
  final Duration closeButtonDelay;

  /// The footnote "Not now" link. The webview page has no equivalent, so
  /// surfaces comparing against it can turn it off.
  final bool showNotNow;

  /// Puts the close button top-right, where the paywall webview has its ×.
  final bool closeButtonOnRight;
  final VoidCallback? onNativeUnavailable;

  @override
  ConsumerState<NativeDonationPage> createState() => _NativeDonationPageState();
}

class _NativeDonationPageState extends ConsumerState<NativeDonationPage> {
  static const _logTag = 'NATIVE_DONATION';
  static const _paywallId = 'paywall_native';
  late List<_Frequency> _offeredFrequencies;
  late _Frequency _selectedFrequency;
  int _selectedAmount = 0;
  bool _isProcessingPayment = false;
  // Which pay button was tapped, so the spinner shows on that one.
  payment_models.PaymentMethodType? _processingMethod;
  bool _didDonate = false;
  bool _dismissLogged = false;
  bool _donateTapLogged = false;
  String? _capturedUserId;
  late bool _closeRevealed = widget.closeButtonDelay == Duration.zero;
  Timer? _closeRevealTimer;

  // Anonymous donors have no account email, so without one the Stripe
  // Customer is created with none: no receipt, and no way into the hosted
  // billing portal (it authenticates by emailing a magic link) — i.e. a
  // recurring charge the donor cannot cancel themselves. The page does not
  // ask for it: the payment sheet does (Apple Pay's, or Stripe's card sheet,
  // which also covers Google Pay), and a known address is sent as it is.
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  // With no known address the field is hidden: the sheet asks for it (see
  // ApplePayService and CardPaymentService) and Stripe stores it on the
  // charge, from which the donate API fills in the Customer. Revealed when a
  // known address is malformed, so the donor can correct or clear it.
  bool _emailRevealed = false;
  // Set once an address was prefilled; keeps the field in place while the
  // donor edits or empties it.
  bool _hadKnownEmail = false;
  final _emailTypoConfirmation = EmailTypoConfirmation();
  String? _emailError;

  // Custom "other amount" field — mirrors the webview arm's input, which the
  // native page lacked. Mutually exclusive with the preset ladder: picking a
  // preset clears this, typing a valid custom value deselects the presets.
  final _customAmountController = TextEditingController();
  final _customAmountFocusNode = FocusNode();
  // Collapsed behind an "Other amount" link until asked for: one fewer input
  // on the page and the pay button sits higher.
  bool _showCustomAmount = false;
  String? _customAmountError;

  /// Resolved in [initState]: paywall config → auth user (incl. tokens) →
  /// the receipt address from an earlier donation → secure storage. A known
  /// address is sent with the payment, so the sheet does not ask again.
  void _resolveKnownEmail() {
    final authRepository = ref.read(authRepositorySyncProvider);
    // getUserEmail() also covers the token-carried address, which currentUser
    // may not have picked up yet.
    for (final candidate in [
      widget.config.email,
      authRepository.getUserEmail(),
      _storedReceiptEmail(),
    ]) {
      if (candidate.isNotNullAndNotEmpty()) {
        _emailController.text = candidate!;
        _hadKnownEmail = true;
        return;
      }
    }
    // Its storage fallback is fire-and-forget and returns before the read
    // lands, so a returning donor still looks anonymous here — read directly.
    unawaited(_prefillEmailFromStorage());
  }

  /// The address typed for an earlier donation's receipt on this install.
  String? _storedReceiptEmail() {
    try {
      return ReceiptEmail.read(ref.read(sharedPreferencesProvider));
    } catch (e) {
      AppLogger.w(_logTag, 'Could not read the stored receipt email: $e');
      return null;
    }
  }

  Future<void> _prefillEmailFromStorage() async {
    try {
      final stored = await SecureStorageService().getUserEmail();
      if (stored.isNullOrEmpty() || !mounted) return;
      // Never clobber an address the donor has already started typing.
      if (_emailController.text.trim().isNotEmpty) return;
      setState(() {
        _emailController.text = stored!;
        _hadKnownEmail = true;
        _emailError = null;
      });
    } catch (e) {
      AppLogger.w(_logTag, 'Could not prefill donor email from storage: $e');
    }
  }

  String get _variantId => widget.config.experiment?.variant ?? 'unknown';

  String get _experimentId {
    final id = widget.config.experiment?.id;
    return (id == null || id.isEmpty) ? 'unknown' : id;
  }

  @override
  void initState() {
    super.initState();
    _capturedUserId = ref.read(authRepositorySyncProvider).currentUser?.id;
    _resolveKnownEmail();

    _resolvePricing();

    if (!_closeRevealed) {
      _closeRevealTimer = Timer(widget.closeButtonDelay, () {
        if (mounted) setState(() => _closeRevealed = true);
      });
    }

    _logPageShown();
  }

  @override
  void didUpdateWidget(covariant NativeDonationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pricingChanged =
        oldWidget.config.currencyCode != widget.config.currencyCode ||
        oldWidget.source != widget.source ||
        _Frequency.values.any((frequency) {
          final key = frequency.configKey;
          return oldWidget.config.isFrequencyOffered(
                    key,
                    source: oldWidget.source,
                  ) !=
                  widget.config.isFrequencyOffered(
                    key,
                    source: widget.source,
                  ) ||
              !listEquals(
                oldWidget.config.effectiveLadder(key, source: oldWidget.source),
                widget.config.effectiveLadder(key, source: widget.source),
              ) ||
              oldWidget.config.effectiveSuggested(
                    key,
                    source: oldWidget.source,
                  ) !=
                  widget.config.effectiveSuggested(key, source: widget.source);
        });
    if (pricingChanged) _resolvePricing(preserveFrequency: true);
  }

  void _resolvePricing({bool preserveFrequency = false}) {
    _offeredFrequencies = _Frequency.values
        .where(
          (f) => widget.config.isFrequencyOffered(
            f.configKey,
            source: widget.source,
          ),
        )
        .toList();
    // The webview page defaults to monthly; fall back to the first offered.
    if (!preserveFrequency ||
        !_offeredFrequencies.contains(_selectedFrequency)) {
      _selectedFrequency = _offeredFrequencies.contains(_Frequency.monthly)
          ? _Frequency.monthly
          : (_offeredFrequencies.isNotEmpty
                ? _offeredFrequencies.first
                : _Frequency.monthly);
    }
    _selectedAmount = _suggestedAmountFor(_selectedFrequency);
    _customAmountController.clear();
    _customAmountError = null;
  }

  @override
  void dispose() {
    _closeRevealTimer?.cancel();
    _emailController.dispose();
    _emailFocusNode.dispose();
    _customAmountController.dispose();
    _customAmountFocusNode.dispose();
    // Parent pager may advance past this tab without an explicit skip tap.
    if (!_didDonate) _logPaywallDismissedNoPayment();
    super.dispose();
  }

  List<int> _ladderFor(_Frequency frequency) =>
      widget.config.effectiveLadder(frequency.configKey, source: widget.source);

  // Same rule as the webview grid: the preset closest to the suggested value
  // gets the "Most popular" badge and starts selected.
  int _suggestedIndexFor(_Frequency frequency) {
    final ladder = _ladderFor(frequency);
    if (ladder.isEmpty) return 0;
    final suggested = widget.config.effectiveSuggested(
      frequency.configKey,
      source: widget.source,
    );
    if (suggested == null) return 0;
    var closestIndex = 0;
    var closestDiff = (ladder.first - suggested).abs();
    for (var i = 1; i < ladder.length; i++) {
      final diff = (ladder[i] - suggested).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  int _suggestedAmountFor(_Frequency frequency) {
    final ladder = _ladderFor(frequency);
    if (ladder.isEmpty) return 0;
    return ladder[_suggestedIndexFor(frequency)];
  }

  // Mirrors the webview's Math.min(...) over the current ladder (minor units).
  int _minimumAmountFor(_Frequency frequency) {
    final ladder = _ladderFor(frequency);
    if (ladder.isEmpty) return 1;
    return ladder.reduce((a, b) => a < b ? a : b);
  }

  void _selectPresetAmount(int amount) {
    // A preset replaces the typed amount, so the keypad has nothing left to
    // do and would only cover the pay buttons.
    _customAmountFocusNode.unfocus();
    setState(() {
      _selectedAmount = amount;
      _customAmountController.clear();
      _customAmountError = null;
    });
  }

  // The field takes a whole number in major units (dollars, not cents) — same
  // as the website's <input type="number" step="1">, which multiplies by the
  // currency's minor-unit factor via unitsToCents before submitting.
  void _onCustomAmountChanged(String raw) {
    final minimum = _minimumAmountFor(_selectedFrequency);
    if (raw.isEmpty) {
      setState(() {
        _customAmountError = null;
        _selectedAmount = 0;
      });
      return;
    }
    final majorUnits = int.tryParse(raw) ?? 0;
    final factor = _minorUnitFactor(widget.config.currencyCode);
    final minorAmount = majorUnits * factor;
    if (minorAmount < minimum) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _customAmountError = l10n.donationMinimumAmount(
          formatCurrencyAmount(minimum, widget.config.currencyCode),
        );
        _selectedAmount = 0;
      });
      return;
    }
    setState(() {
      _customAmountError = null;
      _selectedAmount = minorAmount;
    });
  }

  int _minorUnitFactor(String currency) {
    var factor = 1;
    for (var i = 0; i < minorUnitDigits(currency); i++) {
      factor *= 10;
    }
    return factor;
  }

  void _logPageShown() {
    try {
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.donationPageViewed,
        parameters: {
          AnalyticsEventConstants.paramVariantId: _variantId,
          AnalyticsEventConstants.paramPaywallSource: widget.source,
          AnalyticsEventConstants.paramExperimentId: _experimentId,
          AnalyticsEventConstants.paramExperimentName: _experimentId,
        },
      );
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.paywallPresented,
        parameters: {
          AnalyticsEventConstants.paramPaywallId: _paywallId,
          AnalyticsEventConstants.paramMeditoUserId:
              _capturedUserId ?? 'unknown',
          AnalyticsEventConstants.paramPaywallSource: widget.source,
          AnalyticsEventConstants.paramVariantId: _variantId,
          AnalyticsEventConstants.paramExperimentId: _experimentId,
          AnalyticsEventConstants.paramExperimentName: _experimentId,
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

  void _handleSkip(String method) {
    FirebaseAnalyticsService().logEvent(
      // Not onboarding_donation_skip_tap even for onboarding: this page is
      // pushed from the intro, and that event belongs to the intro's own skip.
      name: 'donation_close_tapped',
      parameters: {'method': method, 'paywall_source': widget.source},
    );
    if (!_didDonate) _logPaywallDismissedNoPayment();
    widget.onNext();
  }

  // defaultTargetPlatform, not Platform.isIOS, so widget tests can exercise
  // the Apple Pay layout.
  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Apple Pay is on offer, or may be: on iOS the field also stays hidden while
  /// the payment methods load, so it does not flash in and out.
  bool get _applePayOfferedOrPending {
    if (!_isIOS) return false;
    // read, not watch: also called from the pay handler. build() already
    // watches this provider in _buildPaymentButtons.
    final methods = ref.read(availablePaymentMethodsProvider);
    if (methods.isLoading) return true;
    return (methods.value ?? const []).any(
      (m) => m.type == payment_models.PaymentMethodType.applePay,
    );
  }

  /// With no known address there is nothing to show: the sheet asks. A known
  /// one is shown where Apple Pay is not offered, so a stale address can be
  /// corrected rather than silently billed against.
  bool get _emailFieldHidden =>
      !_emailRevealed && (_applePayOfferedOrPending || !_hadKnownEmail);

  /// After a donation made without an address on the page: confirm the Stripe
  /// Customer got one from the sheet, and ask the donor if not.
  Future<void> _ensureReceiptEmail() => ensureReceiptEmail(
    context,
    ref,
    logTag: _logTag,
    paywallSource: widget.source,
  );

  Future<void> _handlePay(payment_models.PaymentMethodType method) async {
    if (_isProcessingPayment || _didDonate || _selectedAmount <= 0) return;
    // Lock before email confirmation/storage can yield, so two taps cannot
    // create separate payment attempts. Freeze the amount and cadence tapped.
    setState(() {
      _isProcessingPayment = true;
      _processingMethod = method;
    });
    final amount = _selectedAmount;
    final frequency = _selectedFrequency;
    final currency = widget.config.currencyCode;
    try {
      // No address on the page: the payment sheet collects it, so there is
      // nothing to validate or store here. An address that is present (a
      // known donor's) is still used.
      final emailFromSheet = _emailController.text.trim().isEmpty;
      String? userEmail;
      if (!emailFromSheet) {
        if (!await _emailTypoConfirmation.confirm(context, _emailController)) {
          return;
        }
        if (!mounted) return;
        final typedEmail = _emailController.text.trim();
        if (!_emailPattern.hasMatch(typedEmail)) {
          final l10n = AppLocalizations.of(context)!;
          setState(() {
            // A bad stored address must be visible to be corrected.
            _emailRevealed = true;
            _emailError = typedEmail.isEmpty
                ? l10n.donationEmailRequired
                : l10n.donationEmailInvalid;
          });
          return;
        }
        if (_emailError != null) setState(() => _emailError = null);
        try {
          await ReceiptEmail.save(
            ref.read(sharedPreferencesProvider),
            typedEmail,
          );
        } catch (e) {
          AppLogger.w(_logTag, 'Could not store receipt email: $e');
        }
        userEmail = typedEmail;
      }
      if (!mounted) return;

      if (!_donateTapLogged) {
        _donateTapLogged = true;
        unawaited(
          FirebaseAnalyticsService().logEvent(
            // Not onboarding_donate_now_tap: the intro CTA that opened this
            // page already logged it, as it does for the webview arm.
            name: 'donation_pay_tapped',
            parameters: {'paywall_source': widget.source},
          ),
        );
      }

      // The pay button swaps its label for a spinner; say why, once.
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          AppLocalizations.of(context)!.processingDonation,
          Directionality.of(context),
        ),
      );
      final uiController = ref.read(paymentUIControllerProvider.notifier);
      final authRepository = ref.read(authRepositorySyncProvider);
      final userId = authRepository.currentUser?.id ?? 'unknown';
      _capturedUserId ??= authRepository.currentUser?.id;

      void onSuccess() {
        // Also keeps the pay buttons off while the receipt check below runs.
        setState(() => _didDonate = true);
        if (!emailFromSheet) {
          logDonationEmailOutcome('known', widget.source);
          widget.onNext();
          return;
        }
        unawaited(
          _ensureReceiptEmail().whenComplete(() {
            if (mounted) widget.onNext();
          }),
        );
      }

      late final PaymentResult result;
      switch (frequency) {
        case _Frequency.monthly:
          result = await uiController.initiateMonthlySubscription(
            context: context,
            amount: amount,
            currency: currency,
            paymentMethod: method,
            paywallId: _paywallId,
            userId: userId,
            userEmail: userEmail,
            paywallSource: widget.source,
            variantId: _variantId,
            experimentId: _experimentId,
            campaignMetadata: widget.campaignMetadata,
            onSuccess: onSuccess,
          );
        case _Frequency.yearly:
          result = await uiController.initiateYearlySubscription(
            context: context,
            amount: amount,
            currency: currency,
            paymentMethod: method,
            paywallId: _paywallId,
            userId: userId,
            userEmail: userEmail,
            paywallSource: widget.source,
            variantId: _variantId,
            experimentId: _experimentId,
            campaignMetadata: widget.campaignMetadata,
            onSuccess: onSuccess,
          );
        case _Frequency.oneTime:
          result = await uiController.initiateOneTimePayment(
            context: context,
            amount: amount,
            currency: currency,
            paymentMethod: method,
            paywallId: _paywallId,
            userId: userId,
            userEmail: userEmail,
            paywallSource: widget.source,
            variantId: _variantId,
            experimentId: _experimentId,
            campaignMetadata: widget.campaignMetadata,
            onSuccess: onSuccess,
          );
      }
      if (mounted &&
          result is PaymentFailure &&
          [
            PaymentErrorType.paymentMethodNotSupported,
            PaymentErrorType.applePayNotAvailable,
            PaymentErrorType.googlePayNotAvailable,
          ].contains(result.error?.type)) {
        widget.onNativeUnavailable?.call();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _processingMethod = null;
        });
      }
    }
  }

  void _selectFrequency(_Frequency frequency) {
    if (frequency == _selectedFrequency) return;
    setState(() {
      _selectedFrequency = frequency;
      _selectedAmount = _suggestedAmountFor(frequency);
      _customAmountController.clear();
      _customAmountError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    // The page is a pager tab, not a pushed route, so on Android the system
    // back button would otherwise pop the root route and close the app.
    // Treat back as skip instead (webview-arm parity: its route pops back).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleSkip('back');
      },
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  // Content is one centered block, capped so tablets don't
                  // stretch it edge-to-edge.
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildHero(context, onSurface),
                          const SizedBox(height: 32),
                          if (_offeredFrequencies.length > 1) ...[
                            _buildFrequencyToggle(context, onSurface),
                            const SizedBox(height: 20),
                          ],
                          _buildAmountGrid(context, onSurface),
                          if (_showCustomAmount) ...[
                            const SizedBox(height: 12),
                            _buildCustomAmountField(context, onSurface),
                          ] else
                            _buildOtherAmountLink(context, onSurface),
                          _buildAmountSummary(context, onSurface),
                          const SizedBox(height: 24),
                          if (!_emailFieldHidden) ...[
                            _buildEmailField(context, onSurface),
                            const SizedBox(height: 24),
                          ],
                          _buildPaymentButtons(context),
                          const SizedBox(height: 24),
                          _buildDisclosure(context, onSurface),
                          if (widget.showNotNow) ...[
                            const SizedBox(height: 12),
                            _buildNotNow(context, onSurface),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.showCloseButton)
            Positioned(
              top: 4,
              left: widget.closeButtonOnRight ? null : 4,
              right: widget.closeButtonOnRight ? 4 : null,
              child: Builder(
                builder: (context) {
                  final visible =
                      _closeRevealed ||
                      MediaQuery.accessibleNavigationOf(context);
                  return IgnorePointer(
                    ignoring: !visible,
                    child: ExcludeSemantics(
                      excluding: !visible,
                      child: AnimatedOpacity(
                        opacity: visible ? 1 : 0,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeIn,
                        child: IconButton(
                          onPressed: () => _handleSkip('close'),
                          icon: Icon(
                            Icons.close,
                            size: 22,
                            color: onSurface.withValues(alpha: 0.6),
                          ),
                          tooltip: AppLocalizations.of(context)!.skipForNow,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, Color onSurface) {
    final config = widget.config;
    // No default eyebrow: it only restated the heading. An experiment can
    // still send one.
    final eyebrow = config.heroEyebrow;
    final heading = config.heroHeading ?? _defaultHeading;
    final subcopy = config.heroSubcopy ?? _defaultSubcopy;

    return Column(
      children: [
        if (eyebrow != null && eyebrow.isNotEmpty) ...[
          Text(
            eyebrow.toUpperCase(),
            style: context.text.label.copyWith(color: context.brandAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
        Semantics(
          container: true,
          header: true,
          child: Text(
            heading,
            style: context.text.headline.copyWith(color: onSurface),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subcopy,
          style: context.text.body.copyWith(
            color: onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFrequencyToggle(BuildContext context, Color onSurface) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: _offeredFrequencies.map((frequency) {
          final isSelected = frequency == _selectedFrequency;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              inMutuallyExclusiveGroup: true,
              child: GestureDetector(
                onTap: () => _selectFrequency(frequency),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    frequency.label(l10n),
                    style: context.text.label.copyWith(
                      color: isSelected
                          ? onSurface
                          : onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAmountGrid(BuildContext context, Color onSurface) {
    final ladder = _ladderFor(_selectedFrequency);
    final suggestedIndex = _suggestedIndexFor(_selectedFrequency);
    if (ladder.isEmpty) return const SizedBox.shrink();

    // Mirrors the webview grid: 3 columns, or 2 when the count divides evenly
    // by 2 (but not 3) so the last row is full width.
    final columns = ladder.length % 3 == 0
        ? 3
        : (ladder.length % 2 == 0 ? 2 : 3);

    final rows = <Widget>[];
    for (var start = 0; start < ladder.length; start += columns) {
      final cells = <Widget>[];
      for (var column = 0; column < columns; column++) {
        final index = start + column;
        if (column > 0) cells.add(const SizedBox(width: 10));
        cells.add(
          Expanded(
            child: index < ladder.length
                ? _buildAmountButton(
                    context,
                    onSurface,
                    amount: ladder[index],
                    isSuggested: index == suggestedIndex,
                  )
                : const SizedBox.shrink(),
          ),
        );
      }
      if (start > 0) rows.add(const SizedBox(height: 12));
      rows.add(Row(children: cells));
    }

    return Padding(
      // Headroom for the "Most popular" badge overflowing the first row.
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: rows),
    );
  }

  Widget _buildAmountButton(
    BuildContext context,
    Color onSurface, {
    required int amount,
    required bool isSuggested,
  }) {
    final isSelected =
        amount == _selectedAmount && _customAmountController.text.isEmpty;
    final accent = context.brandAccent;
    final label = formatCurrencyAmount(amount, widget.config.currencyCode);
    final mostPopular = AppLocalizations.of(context)!.donateMostPopular;
    // "COP 20,000", not "$20,000" read as dollars. One label for the tile and
    // its badge; excludeSemantics drops the GestureDetector's tap, so it's
    // given here.
    final spokenLabel = spokenCurrencyAmount(
      amount,
      widget.config.currencyCode,
    );
    void select() => _selectPresetAmount(amount);

    return Semantics(
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      label: isSuggested ? '$spokenLabel, $mostPopular' : spokenLabel,
      excludeSemantics: true,
      onTap: select,
      child: GestureDetector(
        onTap: select,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 52,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              // Selected is filled, like the end-screen chips: a faint tint
              // and a slightly thicker border were near-invisible in the
              // monochrome theme.
              decoration: BoxDecoration(
                color: isSelected ? accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accent : onSurface.withValues(alpha: 0.2),
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              // Long amounts shrink rather than wrap and clip at large text
              // sizes.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: context.text.subtitle.copyWith(
                    color: isSelected ? context.onBrandAccent : onSurface,
                  ),
                ),
              ),
            ),
            if (isSuggested)
              Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      mostPopular,
                      style: context.text.caption.copyWith(color: accent),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Same quiet small-print link as "Not now", with a 48pt touch target.
  Widget _buildOtherAmountLink(BuildContext context, Color onSurface) {
    final faint = onSurface.withValues(alpha: 0.7);
    void reveal() {
      setState(() => _showCustomAmount = true);
      // The field only exists after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _customAmountFocusNode.requestFocus();
      });
    }

    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: _isProcessingPayment ? null : reveal,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                AppLocalizations.of(context)!.donateOtherAmount,
                style: context.text.caption.copyWith(
                  color: faint,
                  decoration: TextDecoration.underline,
                  decorationColor: faint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Mirrors the webview's "other amount" input: whole major units, digit-only,
  // with the same "Minimum amount is X" validation copy.
  Widget _buildCustomAmountField(BuildContext context, Color onSurface) {
    final minimum = _minimumAmountFor(_selectedFrequency);
    final l10n = AppLocalizations.of(context)!;
    final currency = widget.config.currencyCode;
    return MeditoTextField(
      fieldKey: customAmountFieldKey,
      controller: _customAmountController,
      focusNode: _customAmountFocusNode,
      // Keeps the summary line under the field clear of the keyboard, so the
      // typed amount is echoed back where it can be seen.
      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      enabled: !_isProcessingPayment,
      hintText: l10n.donationOtherAmountHint(
        formatCurrencyAmount(minimum, currency),
      ),
      semanticLabel: l10n.donationOtherAmountHint(
        spokenCurrencyAmount(minimum, currency),
      ),
      errorText: _customAmountError,
      onChanged: _onCustomAmountChanged,
    );
  }

  // One line under the amounts, for a preset or a typed amount alike, saying
  // exactly what is about to be given and how often. Two jobs: the cadence is
  // spelled out before the pay sheet (donors cancelling a "monthly" they took
  // for one-time was the top cancellation reason), and a typed amount is
  // echoed back so a stray extra zero is obvious. formatCurrencyAmount and
  // _selectedAmount are already currency-aware (zero-decimal JPY/KRW,
  // 3-decimal KWD/BHD, etc.), so no currency handling is needed here.
  Widget _buildAmountSummary(BuildContext context, Color onSurface) {
    if (_selectedAmount <= 0 || _customAmountError != null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _amountSummary(AppLocalizations.of(context)!),
        style: context.text.caption.copyWith(
          color: onSurface.withValues(alpha: 0.7),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // A recurring gift states what is charged and how often, right where the
  // amount is chosen: about half of cancelling donors said they thought the
  // gift was one-time. The small daily/monthly equivalent rides along while
  // it is small; above the largest preset it stops looking trivial, so it is
  // left out. The ladder is already localized per currency, so it is the
  // yardstick for "large".
  String _amountSummary(AppLocalizations l10n) {
    final currency = widget.config.currencyCode;
    final amount = formatCurrencyAmount(_selectedAmount, currency);
    final ladder = _ladderFor(_selectedFrequency);
    final isGenerous =
        ladder.isNotEmpty &&
        _selectedAmount > ladder.reduce((a, b) => a > b ? a : b);

    switch (_selectedFrequency) {
      case _Frequency.monthly:
        final perDay = (_selectedAmount / 30).round();
        // Rounds to nothing only for amounts far below any real ladder.
        if (isGenerous || perDay <= 0) {
          return l10n.donationRecurringMonthly(amount);
        }
        return l10n.donationCustomMonthly(
          amount,
          formatCurrencyAmount(perDay, currency),
        );
      case _Frequency.yearly:
        final perMonth = (_selectedAmount / 12).round();
        if (isGenerous || perMonth <= 0) {
          return l10n.donationRecurringYearly(amount);
        }
        return l10n.donationCustomYearly(
          amount,
          formatCurrencyAmount(perMonth, currency),
        );
      case _Frequency.oneTime:
        return isGenerous
            ? l10n.donationCustomGenerous
            : l10n.donationCustomOneTime;
    }
  }

  Widget _buildEmailField(BuildContext context, Color onSurface) {
    final l10n = AppLocalizations.of(context)!;
    final field = MeditoTextField(
      fieldKey: donationEmailFieldKey,
      controller: _emailController,
      focusNode: _emailFocusNode,
      // Keeps the helper/error line under the field clear of the keyboard.
      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enabled: !_isProcessingPayment,
      labelText: l10n.donationEmailLabel,
      helperText: l10n.donationEmailHelper,
      helperMaxLines: 2,
      errorText: _emailError,
      onChanged: (_) {
        if (_emailError != null) setState(() => _emailError = null);
      },
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        EmailTypoHint(
          controller: _emailController,
          onAccepted: () {
            if (_emailError != null) setState(() => _emailError = null);
          },
        ),
      ],
    );
  }

  // Intentionally permissive: this gates a donation, so a false reject costs
  // more than a typo reaching Stripe.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');

  Widget _buildPaymentButtons(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Disabled while no valid amount is chosen (a cleared or below-minimum
    // custom amount), rather than a tap that silently does nothing.
    final canPay = !_isProcessingPayment && !_didDonate && _selectedAmount > 0;
    final methodsAsync = ref.watch(availablePaymentMethodsProvider);
    final methods = methodsAsync.value ?? const [];
    final hasApplePay =
        _isIOS &&
        methods.any(
          (m) =>
              m.type == payment_models.PaymentMethodType.applePay &&
              m.isAvailable,
        );

    final applePaySpinning =
        _isProcessingPayment &&
        _processingMethod == payment_models.PaymentMethodType.applePay;

    return Column(
      children: [
        if (hasApplePay) ...[
          // Apple Pay offered first on iOS (App Review Guideline 3.2.1(vi)).
          ApplePayDonateButton(
            onPressed: canPay
                ? () => _handlePay(payment_models.PaymentMethodType.applePay)
                : null,
            isProcessing: applePaySpinning,
            onLightSurface:
                Theme.of(context).scaffoldBackgroundColor.computeLuminance() >
                0.5,
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          // With a wallet button present it is the primary action — card drops
          // to an outlined secondary. Without one, card stays the filled CTA.
          child: ElevatedButton(
            key: donationPayButtonKey,
            onPressed: canPay
                ? () => _handlePay(payment_models.PaymentMethodType.card)
                : null,
            style: hasApplePay
                ? ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: Colors.transparent,
                    foregroundColor: context.brandAccent,
                    elevation: 0,
                    side: BorderSide(
                      color: context.brandAccent.withValues(alpha: 0.6),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )
                : ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: context.brandAccent,
                    foregroundColor: context.onBrandAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
            child: _isProcessingPayment && !applePaySpinning
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: hasApplePay
                          ? context.brandAccent
                          : context.onBrandAccent,
                      // Otherwise the disabled button has no name while it
                      // spins.
                      semanticsLabel: l10n.processingDonation,
                    ),
                  )
                : Text(
                    hasApplePay ? l10n.donateWithCard : _payLabel(l10n),
                    style: context.text.inherited.subtitle,
                    textAlign: TextAlign.center,
                  ),
          ),
        ),
      ],
    );
  }

  // The sole pay button names the amount ("Donate $5") so the figure is on
  // the thing being tapped; the cadence is left to the summary line above.
  // With no valid amount it is disabled and falls back to plain "Donate".
  String _payLabel(AppLocalizations l10n) {
    if (_selectedAmount <= 0) return l10n.donateTitle;
    return l10n.donateAmountOnce(
      formatCurrencyAmount(_selectedAmount, widget.config.currencyCode),
    );
  }

  Widget _buildDisclosure(BuildContext context, Color onSurface) {
    final l10n = AppLocalizations.of(context)!;
    // 0.7, not 0.5: small print still needs to be legible.
    final faint = onSurface.withValues(alpha: 0.7);
    return Column(
      children: [
        Text(
          _registrationCopy,
          style: context.text.caption.copyWith(color: faint),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bundled SVG, not a Material icon: a new icon-font glyph is an
            // unpatchable asset diff (see Apple Pay button above).
            MeditoIcon(assetName: MeditoIcons.shield, color: faint, size: 13),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                l10n.donationStripeTrust,
                style: context.text.caption.copyWith(color: faint),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Quiet skip: footnote-sized "Not now" under the disclosure, styled like
  /// the surrounding small print rather than a button. Still announced as a
  /// button, with a 48pt touch target around the small text.
  Widget _buildNotNow(BuildContext context, Color onSurface) {
    final faint = onSurface.withValues(alpha: 0.7);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => _handleSkip('not_now'),
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                AppLocalizations.of(context)!.donateNotNow,
                style: context.text.caption.copyWith(
                  color: faint,
                  decoration: TextDecoration.underline,
                  decorationColor: faint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
