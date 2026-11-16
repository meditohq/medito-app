import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/widgets/medito_icon.dart';

/// The one frame every card under the end-screen stats uses (reminder,
/// account, usage-stats re-consent, donation, thank-you, how-do-you-feel,
/// rating). Same border, padding, type scale and corner slot, so the stacked
/// cards read as one family instead of each picking its own sizes.
///
/// [inverted] is the brand-coloured donation family; the rest sit on the
/// regular card colour.
class EndScreenCard extends StatelessWidget {
  const EndScreenCard({
    super.key,
    required this.title,
    this.body,
    this.child,
    this.corner,
    this.inverted = false,
    this.bottomPadding = 20,
  });

  final String title;
  final String? body;

  /// Actions or anything else below the body.
  final Widget? child;

  /// ✕ or ? pinned to the top-right corner, outside the content padding so
  /// its tap target doesn't push the title row taller.
  final EndScreenCardCorner? corner;

  final bool inverted;

  /// Smaller when the card ends in a text button, which brings its own
  /// padding.
  final double bottomPadding;

  /// Foreground colour cards' own widgets (buttons, footers) should use.
  static Color foreground(BuildContext context, {bool inverted = false}) =>
      inverted
      ? context.onBrandAccent
      : Theme.of(context).colorScheme.onSurface;

  static TextStyle titleStyle(BuildContext context, {bool inverted = false}) =>
      context.text.title.copyWith(
        color: foreground(context, inverted: inverted),
      );

  static TextStyle bodyStyle(BuildContext context, {bool inverted = false}) =>
      context.text.body.copyWith(
        color: foreground(context, inverted: inverted).withValues(alpha: 0.8),
      );

  /// Button labels, filled or outlined; pass the colour for filled buttons.
  static TextStyle buttonStyle(BuildContext context, {Color? color}) =>
      context.text.subtitle.copyWith(color: color);

  /// "Not now" links and footers.
  static TextStyle secondaryStyle(BuildContext context, {Color? color}) =>
      context.text.label.copyWith(color: color);

  @override
  Widget build(BuildContext context) {
    final fg = foreground(context, inverted: inverted);
    final corner = this.corner;

    return HomeGradientBorder(
      backgroundColor: inverted
          ? context.brandAccent
          : Theme.of(context).cardColor,
      borderRadius: 14,
      borderWidth: 0.5,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: corner == null ? 0 : 24),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: titleStyle(context, inverted: inverted),
                    ),
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 6),
                  Text(body!, style: bodyStyle(context, inverted: inverted)),
                ],
                if (child != null) ...[const SizedBox(height: 16), child!],
              ],
            ),
          ),
          if (corner != null)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: corner.tooltip,
                icon: MeditoIcon(
                  assetName: corner.icon,
                  size: 20,
                  color: fg.withValues(alpha: 0.6),
                ),
                onPressed: corner.onPressed,
                padding: EdgeInsets.zero,
                // 48pt tap target (accessibility minimum).
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EndScreenCardCorner {
  const EndScreenCardCorner({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  /// A [MeditoIcons] asset.
  final String icon;
  final String tooltip;
  final VoidCallback onPressed;
}
