import 'package:flutter/material.dart';

class HomeGradientBorder extends StatelessWidget {
  const HomeGradientBorder({
    required this.backgroundColor,
    required this.borderRadius,
    required this.borderWidth,
    required this.child,
    super.key,
    this.lightBlend = 0.26,
    this.darkBlend = 0.88,
  });

  final Color backgroundColor;
  final double borderRadius;
  final double borderWidth;
  final Widget child;
  final double lightBlend;
  final double darkBlend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Tone the bezel down in light mode — the same blends that read as a soft
    // inner glow on dark surfaces look like a heavy 3D edge on white.
    final effectiveLightBlend = isDark ? lightBlend : lightBlend * 0.55;
    final effectiveDarkBlend = isDark ? darkBlend : darkBlend * 0.18;
    final lightColor =
        Color.lerp(backgroundColor, Colors.white, effectiveLightBlend) ??
        backgroundColor;
    final darkColor =
        Color.lerp(backgroundColor, Colors.black, effectiveDarkBlend) ??
        backgroundColor;
    final innerRadius = (borderRadius - borderWidth).clamp(0.0, borderRadius);

    // Vertical gradient (top → bottom) rather than diagonal: diagonals only
    // land the light/dark at opposite corners, so on wide-short cards the
    // top and bottom edges end up flat mid-tone. A pure vertical gradient
    // highlights the top rim and shadows the bottom rim consistently for
    // any aspect ratio.
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lightColor, darkColor],
            stops: const [0.0, 1.0],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(borderWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(innerRadius),
            child: ColoredBox(color: backgroundColor, child: child),
          ),
        ),
      ),
    );
  }
}
