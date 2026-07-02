import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/stripe/payment_method_model.dart'
    as payment_models;
import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/logger.dart';

enum _Frequency {
  oneTime('oneTime', 'one_time', 'One-time'),
  monthly('monthly', 'monthly', 'Monthly'),
  yearly('yearly', 'yearly', 'Yearly');

  const _Frequency(this.configKey, this.analyticsKey, this.label);

  final String configKey;
  final String analyticsKey;
  final String label;
}

// Native fallback copy mirrors the paywall webview page (which is
// English-only; localized copy arrives via the experiment config).
const _defaultEyebrow = 'Help keep Medito free';
const _defaultHeading = 'Keep meditation free\nfor the next million';
const _defaultSubcopy =
    '4.1 million people meditate with Medito for free. '
    'No ads, no paywalls — funded entirely by donors like you.';
const _mostPopularLabel = 'Most popular';
const _supportCta = 'Support Medito';
const _cardCta = 'Pay with card';
const _disclosureCopy =
    'Your donation helps keep Medito free for everyone — no ads, no paywalls. '
    'You will receive an email confirmation shortly.\n'
    'Stichting Medito · Non-profit registered in the Netherlands · KvK 75284251';
const _stripeTrustCopy = 'Secure payment powered by Stripe';

// Stripe zero-decimal currencies: amounts are already in whole units.
const _zeroDecimalCurrencies = {
  'bif', 'clp', 'djf', 'gnf', 'jpy', 'kmf', 'krw', 'mga',
  'pyg', 'rwf', 'ugx', 'vnd', 'vuv', 'xaf', 'xof', 'xpf',
};

String _formatAmount(int amount, String currency) {
  final code = currency.toLowerCase();
  final isZeroDecimal = _zeroDecimalCurrencies.contains(code);
  final value = isZeroDecimal ? amount.toDouble() : amount / 100;
  final wholeNumber = value == value.roundToDouble();
  final format = NumberFormat.simpleCurrency(
    name: code.toUpperCase(),
    decimalDigits: (isZeroDecimal || wholeNumber) ? 0 : 2,
  );
  return format.format(value);
}

/// Native (Dart) rendering of the onboarding donation paywall — an inline
/// pager-tab body, not a pushed route. Renders the same server-resolved
/// `/paywall` config the webview page consumes; the caller is responsible for
/// loading [config] and falling back to the webview flow when it can't.
class NativeDonationPage extends ConsumerStatefulWidget {
  const NativeDonationPage({
    super.key,
    required this.config,
    required this.onNext,
    required this.source,
  });

  final PaywallConfigModel config;
  final VoidCallback onNext;
  final String source;

  @override
  ConsumerState<NativeDonationPage> createState() =>
      _NativeDonationPageState();
}

class _NativeDonationPageState extends ConsumerState<NativeDonationPage> {
  static const _logTag = 'NATIVE_DONATION';
  static const _paywallId = 'paywall_native';
  // Matches the webview page's delayed close affordance, so users read the
  // page before the escape hatch appears.
  static const _skipDelay = Duration(seconds: 5);

  late final List<_Frequency> _offeredFrequencies;
  late _Frequency _selectedFrequency;
  int _selectedAmount = 0;
  bool _isProcessingPayment = false;
  bool _didDonate = false;
  bool _dismissLogged = false;
  bool _donateTapLogged = false;
  bool _showSkip = false;
  String? _capturedUserId;
  Timer? _skipTimer;

  String get _variantId => widget.config.experiment?.variant ?? 'unknown';

  String get _experimentId {
    final id = widget.config.experiment?.id;
    return (id == null || id.isEmpty) ? 'unknown' : id;
  }

  @override
  void initState() {
    super.initState();
    _capturedUserId = ref.read(authRepositorySyncProvider).currentUser?.id;

    _offeredFrequencies = _Frequency.values
        .where(
          (f) => widget.config.isFrequencyOffered(
            f.configKey,
            source: widget.source,
          ),
        )
        .toList();
    // The webview page defaults to monthly; fall back to the first offered.
    _selectedFrequency = _offeredFrequencies.contains(_Frequency.monthly)
        ? _Frequency.monthly
        : (_offeredFrequencies.isNotEmpty
              ? _offeredFrequencies.first
              : _Frequency.monthly);
    _selectedAmount = _suggestedAmountFor(_selectedFrequency);

    _skipTimer = Timer(_skipDelay, () {
      if (mounted) setState(() => _showSkip = true);
    });

    _logPageShown();
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
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

  void _logPageShown() {
    try {
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.donationPageViewed,
        parameters: {
          AnalyticsEventConstants.paramVariantId: _variantId,
          AnalyticsEventConstants.paramPaywallSource: widget.source,
          AnalyticsEventConstants.paramExperimentId: _experimentId,
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

  void _handleSkip() {
    FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventOnboardingDonationSkipTap,
    );
    if (!_didDonate) _logPaywallDismissedNoPayment();
    widget.onNext();
  }

  Future<void> _handlePay(payment_models.PaymentMethodType method) async {
    if (_isProcessingPayment || _selectedAmount <= 0) return;

    if (!_donateTapLogged) {
      _donateTapLogged = true;
      unawaited(
        FirebaseAnalyticsService().logEvent(
          name: FirebaseAnalyticsService.eventOnboardingDonateNowTap,
        ),
      );
    }

    setState(() => _isProcessingPayment = true);
    try {
      final uiController = ref.read(paymentUIControllerProvider.notifier);
      final authRepository = ref.read(authRepositorySyncProvider);
      final userId = authRepository.currentUser?.id ?? 'unknown';
      _capturedUserId ??= authRepository.currentUser?.id;
      final userEmail = widget.config.email ?? authRepository.currentUser?.email;
      final currency = widget.config.currencyCode;
      final amount = _selectedAmount;

      void onSuccess() {
        _didDonate = true;
        widget.onNext();
      }

      switch (_selectedFrequency) {
        case _Frequency.monthly:
          await uiController.initiateMonthlySubscription(
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
            onSuccess: onSuccess,
          );
        case _Frequency.yearly:
          await uiController.initiateYearlySubscription(
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
            onSuccess: onSuccess,
          );
        case _Frequency.oneTime:
          await uiController.initiateOneTimePayment(
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
            onSuccess: onSuccess,
          );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  void _selectFrequency(_Frequency frequency) {
    if (frequency == _selectedFrequency) return;
    setState(() {
      _selectedFrequency = frequency;
      _selectedAmount = _suggestedAmountFor(frequency);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHero(context, onSurface),
                const SizedBox(height: 24),
                Column(
                  children: [
                    if (_offeredFrequencies.length > 1) ...[
                      _buildFrequencyToggle(context, onSurface),
                      const SizedBox(height: 20),
                    ],
                    _buildAmountGrid(context, onSurface),
                    const SizedBox(height: 24),
                    _buildPaymentButtons(context),
                    const SizedBox(height: 16),
                    _buildDisclosure(context, onSurface),
                    _buildSkip(context),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHero(BuildContext context, Color onSurface) {
    final config = widget.config;
    final eyebrow = config.heroEyebrow ?? _defaultEyebrow;
    final heading = config.heroHeading ?? _defaultHeading;
    final subcopy = config.heroSubcopy ?? _defaultSubcopy;

    return Column(
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: context.brandPurple,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          heading,
          style: TextStyle(
            color: onSurface,
            fontSize: 26,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          subcopy,
          style: TextStyle(
            color: onSurface.withValues(alpha: 0.7),
            fontSize: 15,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFrequencyToggle(BuildContext context, Color onSurface) {
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
              child: GestureDetector(
                onTap: () => _selectFrequency(frequency),
                child: Container(
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
                    frequency.label,
                    style: TextStyle(
                      color: isSelected
                          ? onSurface
                          : onSurface.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
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
    final isSelected = amount == _selectedAmount;
    final accent = context.brandPurple;
    final label = _formatAmount(amount, widget.config.currencyCode);

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: () => setState(() => _selectedAmount = amount),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.08)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? accent
                      : onSurface.withValues(alpha: 0.2),
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? accent : onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
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
                      _mostPopularLabel,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentButtons(BuildContext context) {
    final methodsAsync = ref.watch(availablePaymentMethodsProvider);
    final methods = methodsAsync.value ?? const [];
    final hasApplePay =
        Platform.isIOS &&
        methods.any(
          (m) => m.type == payment_models.PaymentMethodType.applePay,
        );

    return Column(
      children: [
        if (hasApplePay) ...[
          // Apple Pay offered first on iOS (App Review Guideline 3.2.1(vi)).
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isProcessingPayment
                  ? null
                  : () =>
                        _handlePay(payment_models.PaymentMethodType.applePay),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.apple, size: 22),
                  SizedBox(width: 2),
                  Text(
                    'Pay',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isProcessingPayment
                ? null
                : () => _handlePay(payment_models.PaymentMethodType.card),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brandPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isProcessingPayment
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    hasApplePay ? _cardCta : _supportCta,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclosure(BuildContext context, Color onSurface) {
    final faint = onSurface.withValues(alpha: 0.5);
    return Column(
      children: [
        Text(
          _disclosureCopy,
          style: TextStyle(color: faint, fontSize: 12, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 13, color: faint),
            const SizedBox(width: 4),
            Text(
              _stripeTrustCopy,
              style: TextStyle(color: faint, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSkip(BuildContext context) {
    return AnimatedOpacity(
      opacity: _showSkip ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      child: IgnorePointer(
        ignoring: !_showSkip,
        child: TextButton(
          onPressed: _handleSkip,
          child: Text(AppLocalizations.of(context)!.skipForNow),
        ),
      ),
    );
  }
}
