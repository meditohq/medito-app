import 'package:flutter/material.dart';

/// The app's flat card surface: a solid fill with a 0.5px hairline tinted
/// from the fill itself, so it works on the card colour, on brand purple
/// (donation card) and on images alike.
///
/// The name predates the flat look — this used to paint a vertical
/// light-to-dark gradient rim. The class and constructor are unchanged so the
/// call sites across home, settings, explore, track and end screen all moved
/// to the flat surface together.
class HomeGradientBorder extends StatelessWidget {
  const HomeGradientBorder({
    required this.backgroundColor,
    required this.borderRadius,
    required this.borderWidth,
    required this.child,
    super.key,
    @Deprecated('No longer used; the surface is flat.') this.lightBlend = 0.26,
    @Deprecated('No longer used; the surface is flat.') this.darkBlend = 0.88,
  });

  final Color backgroundColor;
  final double borderRadius;
  final double borderWidth;
  final Widget child;
  final double lightBlend;
  final double darkBlend;

  static const _hairlineBlendDark = 0.14;
  static const _hairlineBlendLight = 0.10;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hairline = isDark
        ? Color.lerp(backgroundColor, Colors.white, _hairlineBlendDark)!
        : Color.lerp(backgroundColor, Colors.black, _hairlineBlendLight)!;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: hairline, width: borderWidth),
      ),
      child: child,
    );
  }
}
