import 'package:flutter/material.dart';

/// Collapses outgoing content so the sections below move with its exit.
class AnimatedEndScreenSection extends StatelessWidget {
  const AnimatedEndScreenSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      // A stack would retain the outgoing section's height until it disappears.
      layoutBuilder: (currentChild, previousChildren) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [...previousChildren, ?currentChild],
      ),
      child: child,
    );
  }
}
