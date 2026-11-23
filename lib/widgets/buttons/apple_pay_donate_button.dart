import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart'
    show PlatformButtonStyle, PlatformButtonType, PlatformPayButton;
import 'package:medito/constants/theme/medito_text.dart';
import 'package:medito/l10n/app_localizations.dart';

/// Apple's own "Donate with Apple Pay" button (PKPaymentButton), as the HIG
/// asks for wherever a tap opens the Apple Pay sheet directly. Black on a
/// light surface, white on a dark one, per the same guidelines.
///
/// The native button is an iOS platform view with no disabled or busy state,
/// so both are handled here: a null [onPressed] dims it and blocks taps, and
/// [isProcessing] swaps it for a spinner. Off iOS (widget tests, previews) a
/// plain stand-in with the same name is drawn instead.
class ApplePayDonateButton extends StatelessWidget {
  const ApplePayDonateButton({
    super.key,
    required this.onPressed,
    required this.onLightSurface,
    this.isProcessing = false,
    this.height = 48,
    this.semanticLabel,
  });

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Whether the surface behind the button is light (picks black vs white).
  final bool onLightSurface;

  final bool isProcessing;
  final double height;

  /// Spoken name; defaults to "Donate with Apple Pay".
  final String? semanticLabel;

  static const int _radius = 8;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final background = onLightSurface ? Colors.black : Colors.white;
    final foreground = onLightSurface ? Colors.white : Colors.black;
    final shape = BorderRadius.circular(_radius.toDouble());

    if (isProcessing) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background.withValues(alpha: 0.7),
          borderRadius: shape,
        ),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: foreground,
            // Otherwise the busy button has no name while it spins.
            semanticsLabel: l10n.processingDonation,
          ),
        ),
      );
    }

    final enabled = onPressed != null;
    final Widget button = !kIsWeb && Platform.isIOS
        ? PlatformPayButton(
            type: PlatformButtonType.donate,
            appearance: onLightSurface
                ? PlatformButtonStyle.black
                : PlatformButtonStyle.white,
            borderRadius: _radius,
            constraints: BoxConstraints.tightFor(height: height),
            onPressed: onPressed ?? () {},
          )
        : ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              shape: RoundedRectangleBorder(borderRadius: shape),
            ),
            child: Text(
              l10n.donateWithApplePay,
              style: context.text.inherited.subtitle,
            ),
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? l10n.donateWithApplePay,
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: enabled
            ? button
            : IgnorePointer(child: Opacity(opacity: 0.5, child: button)),
      ),
    );
  }
}
