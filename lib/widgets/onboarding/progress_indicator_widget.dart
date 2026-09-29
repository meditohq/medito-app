import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';

/// Onboarding progress shown as a horizontal bar that fills left-to-right as
/// the user advances, paired with a "Step X of Y" label. The fill animates
/// smoothly between steps rather than snapping.
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final step = (currentIndex + 1).clamp(1, totalSteps);
    final target = totalSteps == 0 ? 0.0 : step / totalSteps;
    final trackColor = (isDark ? Colors.white : Colors.black).withValues(
      alpha: isDark ? 0.14 : 0.10,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 200,
              height: 4,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: target),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: trackColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.brandPurple,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.onboardingStepIndicator(step, totalSteps),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
