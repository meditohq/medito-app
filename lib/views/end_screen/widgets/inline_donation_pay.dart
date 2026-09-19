import 'package:flutter/material.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/stripe/payment_method_model.dart'
    as payment_models;
import 'package:medito/utils/currency.dart';

/// Stable handles for tests.
@visibleForTesting
const inlineDonationEmailFieldKey = Key('inline_donation_email_field');
@visibleForTesting
const inlineDonationPayButtonKey = Key('inline_donation_pay_button');
@visibleForTesting
const inlineDonationOtherAmountKey = Key('inline_donation_other_amount');

typedef InlinePayCallback =
    Future<void> Function({
      required int amount,
      required String email,
      required payment_models.PaymentMethodType method,
    });

/// Variant B body of the end-screen donation card (`end_screen_inline_pay`):
/// the localized monthly ladder as chips, a one-tap pay button, and an
/// "Other amount" escape to the full paywall. Pure presentation — the parent
/// owns config loading, payment, analytics and the experiment gate — so it
/// is testable without Stripe or Riverpod.
///
/// Drawn on the brand-purple card, so every foreground uses
/// `context.onBrandPurple` like the control CTA does.
class InlineDonationPay extends StatefulWidget {
  const InlineDonationPay({
    super.key,
    required this.currencyCode,
    required this.ladder,
    required this.suggestedAmount,
    required this.knownEmail,
    required this.applePayAvailable,
    required this.isProcessing,
    required this.onPay,
    required this.onOtherAmount,
  });

  /// ISO code, lower-case as the paywall config supplies it.
  final String currencyCode;

  /// Monthly amounts in minor units, ascending, as served for `end_screen`.
  final List<int> ladder;

  /// Preselected amount (minor units); the closest chip gets the badge.
  final int? suggestedAmount;

  /// Donor email already on file, or null to ask for one inline. Stripe
  /// creates the Customer before the sheet opens, so an address captured
  /// later never reaches the receipt / billing portal.
  final String? knownEmail;

  /// True only on iOS with a wallet: renders the Apple Pay button and
  /// confirms through the platform sheet. Otherwise the button opens the
  /// Stripe PaymentSheet (which offers Google Pay on Android by itself).
  final bool applePayAvailable;

  final bool isProcessing;
  final InlinePayCallback onPay;
  final VoidCallback onOtherAmount;

  @override
  State<InlineDonationPay> createState() => _InlineDonationPayState();
}

class _InlineDonationPayState extends State<InlineDonationPay> {
  late int _selectedAmount;
  final _emailController = TextEditingController();
  String? _emailError;

  // Intentionally permissive: a false reject costs more than a typo.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');

  bool get _asksForEmail =>
      widget.knownEmail == null || widget.knownEmail!.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _selectedAmount = _initialAmount();
  }

  @override
  void didUpdateWidget(covariant InlineDonationPay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ladder != widget.ladder &&
        !widget.ladder.contains(_selectedAmount)) {
      _selectedAmount = _initialAmount();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  int _initialAmount() {
    if (widget.ladder.isEmpty) return 0;
    return widget.ladder[_suggestedIndex()];
  }

  // Same rule as the webview grid and native page: the chip closest to the
  // suggested value is preselected and badged.
  int _suggestedIndex() {
    final ladder = widget.ladder;
    final suggested = widget.suggestedAmount;
    if (ladder.isEmpty || suggested == null) return 0;
    var closest = 0;
    var closestDiff = (ladder.first - suggested).abs();
    for (var i = 1; i < ladder.length; i++) {
      final diff = (ladder[i] - suggested).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        closest = i;
      }
    }
    return closest;
  }

  Future<void> _submit() async {
    if (widget.isProcessing || _selectedAmount <= 0) return;

    var email = widget.knownEmail?.trim() ?? '';
    if (_asksForEmail) {
      email = _emailController.text.trim();
      if (!_emailPattern.hasMatch(email)) {
        final l10n = AppLocalizations.of(context)!;
        setState(
          () => _emailError = email.isEmpty
              ? l10n.donationEmailRequired
              : l10n.donationEmailInvalid,
        );
        return;
      }
    }
    if (_emailError != null) setState(() => _emailError = null);

    await widget.onPay(
      amount: _selectedAmount,
      email: email,
      method: widget.applePayAvailable
          ? payment_models.PaymentMethodType.applePay
          : payment_models.PaymentMethodType.card,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fg = context.onBrandPurple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildChips(context, fg),
        if (_asksForEmail) ...[
          const SizedBox(height: 14),
          _buildEmailField(context, fg, l10n),
        ],
        const SizedBox(height: 14),
        widget.applePayAvailable
            ? _buildApplePayButton(context, l10n)
            : _buildCardButton(context, l10n),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                l10n.donateMonthlyDisclosure,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.7),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              key: inlineDonationOtherAmountKey,
              onTap: widget.isProcessing ? null : widget.onOtherAmount,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  l10n.donateOtherAmount,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: fg,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChips(BuildContext context, Color fg) {
    final l10n = AppLocalizations.of(context)!;
    final suggestedIndex = _suggestedIndex();
    final cells = <Widget>[];
    for (var i = 0; i < widget.ladder.length; i++) {
      if (i > 0) cells.add(const SizedBox(width: 8));
      cells.add(
        Expanded(
          child: _buildChip(
            context,
            fg,
            amount: widget.ladder[i],
            isSuggested: i == suggestedIndex,
            badge: l10n.donateMostPopular,
          ),
        ),
      );
    }
    return Padding(
      // Headroom for the badge overflowing the top of the chips.
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: cells),
    );
  }

  Widget _buildChip(
    BuildContext context,
    Color fg, {
    required int amount,
    required bool isSuggested,
    required String badge,
  }) {
    final isSelected = amount == _selectedAmount;
    final label = formatCurrencyAmount(amount, widget.currencyCode);

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: widget.isProcessing
            ? null
            : () => setState(() => _selectedAmount = amount),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? fg : Colors.transparent,
                border: Border.all(
                  color: isSelected ? fg : fg.withValues(alpha: 0.5),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? context.brandPurple : fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: context.brandPurple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: fg,
                        fontSize: 9,
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

  Widget _buildEmailField(
    BuildContext context,
    Color fg,
    AppLocalizations l10n,
  ) {
    return TextField(
      key: inlineDonationEmailFieldKey,
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enabled: !widget.isProcessing,
      style: TextStyle(color: fg, fontSize: 14),
      cursorColor: fg,
      decoration: InputDecoration(
        isDense: true,
        hintText: l10n.donationEmailLabel,
        hintStyle: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 14),
        helperText: _emailError == null ? l10n.donationEmailHelper : null,
        helperStyle: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11),
        errorText: _emailError,
        errorStyle: TextStyle(color: fg, fontSize: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: fg.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: fg),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: fg),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: fg),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (_) {
        if (_emailError != null) setState(() => _emailError = null);
      },
    );
  }

  String get _amountLabel =>
      formatCurrencyAmount(_selectedAmount, widget.currencyCode);

  Widget _buildApplePayButton(BuildContext context, AppLocalizations l10n) {
    // White button per Apple Pay HIG on a coloured background; "Donate with
    //  Pay" is Apple's official nonprofit variant. U+F8FF is the Apple logo
    // glyph in the iOS system font, so this is only ever built on iOS.
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        key: inlineDonationPayButtonKey,
        onPressed: widget.isProcessing ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: widget.isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            // Long localized amounts (R$ 1.000, ₹2,000) must never wrap or
            // overflow the wallet button — shrink the whole label instead.
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${l10n.donateWithApplePayPrefix} ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      '',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Pay · $_amountLabel',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCardButton(BuildContext context, AppLocalizations l10n) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        key: inlineDonationPayButtonKey,
        onPressed: widget.isProcessing ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.onBrandPurple,
          foregroundColor: context.brandPurple,
          disabledBackgroundColor: context.onBrandPurple.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: widget.isProcessing
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.brandPurple,
                ),
              )
            : Text(
                l10n.donateAmountPerMonth(_amountLabel),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
