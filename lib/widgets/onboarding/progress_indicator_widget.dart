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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
                  ? context.brandPurple
                  : isDark
                      ? Colors.white24
                      : ColorConstants.lightGrey,
            ),
          );
        }),
      ),
    );
  }
}
