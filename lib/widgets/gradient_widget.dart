import 'package:Medito/utils/colors.dart';
import 'package:flutter/material.dart';

class GradientWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        height: height,
        child: child,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colorsList()),
        ),
      ),
    );
  }

  List<Color> colorsList() => [
        primaryColor ?? MeditoColors.transparent,
        primaryColor?.withOpacity(0) ?? MeditoColors.transparent,
      ];

  final height;
  final Color? primaryColor;
  final opacity;
  final child;

  GradientWidget(
      {this.height = 350.0, this.primaryColor, this.opacity = 1.0, this.child});
}
