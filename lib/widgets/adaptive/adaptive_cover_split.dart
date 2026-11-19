import 'package:flutter/material.dart';

/// Shared by the pack and track screens so the cover pane lines up when one
/// opens the other.
abstract final class AdaptiveCoverSplit {
  /// From this window width the cover fills a pane of its own beside the
  /// content (Material's expanded class: an unfolded foldable, a landscape
  /// tablet and most landscape phones).
  static const breakpoint = 840.0;

  /// The two-pane screen's own width cap.
  static const maxWidth = 1200.0;

  static bool isWide(double width) => width >= breakpoint;

  /// Half the window, so on a foldable the cover fills one side of the hinge
  /// and the content the other.
  static double coverWidth(double width) => (width * 0.5).clamp(320.0, 520.0);
}

/// Fades the foot of a full-height cover into the page behind the action bar
/// that floats over it, so the bar's icons stay readable on any artwork.
class CoverBarFade extends StatelessWidget {
  const CoverBarFade({super.key});

  @override
  Widget build(BuildContext context) {
    final barHeight = MediaQuery.paddingOf(context).bottom;
    if (barHeight <= 0) return const SizedBox.shrink();
    final page = Theme.of(context).scaffoldBackgroundColor;
    return Align(
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        child: Container(
          height: barHeight + 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [page.withValues(alpha: 0), page.withValues(alpha: 0.85)],
            ),
          ),
        ),
      ),
    );
  }
}
