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
    final effectiveLightBlend = isDark ? lightBlend : lightBlend * 0.4;
    final effectiveDarkBlend = isDark ? darkBlend : darkBlend * 0.25;
    final lightColor =
        Color.lerp(backgroundColor, Colors.white, effectiveLightBlend) ??
        backgroundColor;
    final darkColor =
        Color.lerp(backgroundColor, Colors.black, effectiveDarkBlend) ??
        backgroundColor;
    final innerRadius = (borderRadius - borderWidth).clamp(0.0, borderRadius);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [lightColor, darkColor],
            stops: const [0.35, 0.75],
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
