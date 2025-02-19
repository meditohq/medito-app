import 'package:flutter/material.dart';
import 'package:medito/constants/colors/color_constants.dart';

class OnboardingProgressIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalSteps;

  const OnboardingProgressIndicator({
    super.key,
    required this.currentIndex,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalSteps, (index) {
          return Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == currentIndex
                  ? ColorConstants.lightPurple
                  : Colors.white24,
            ),
          );
        }),
      ),
    );
  }
}
