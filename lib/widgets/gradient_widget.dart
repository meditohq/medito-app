import 'package:Medito/utils/colors.dart';
import 'package:flutter/material.dart';

class GradientWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          primaryColor?.withOpacity(0.6) ?? MeditoColors.moonlight,
          MeditoColors.midnight,
        ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
    );
  }

  final height;
  final primaryColor;

  GradientWidget({this.height = 350.0, this.primaryColor});
}
