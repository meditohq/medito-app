import 'package:flutter/material.dart';
import 'package:medito/widgets/adaptive/adaptive_content.dart';

/// Keeps every onboarding step in the same readable column on wide windows.
class OnboardingContent extends StatelessWidget {
  const OnboardingContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: AdaptiveContent(child: child),
    ),
  );
}
