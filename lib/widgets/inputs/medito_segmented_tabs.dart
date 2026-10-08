import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';

/// The app's tab switcher: a card-coloured track with the selected segment
/// filled in the brand accent, like a primary button. Used wherever a screen
/// or dialog switches between a few views (Timer/Stopwatch, Stats/History,
/// Single day/Date range, cm/in).
///
/// Pass [position] (a [TabController.animation]) to have the indicator follow
/// a swipe between pages; otherwise it animates to [selectedIndex].
class MeditoSegmentedTabs extends StatelessWidget {
  const MeditoSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.position,
    this.height = 48,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Animation<double>? position;
  final double height;

  /// The themed buttons' corner radius; the track adds the inset around it so
  /// the two corners stay concentric.
  static const _buttonRadius = 8.0;
  static const _inset = 4.0;
  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = labels.length;

    Alignment alignmentFor(double index) =>
        Alignment(count < 2 ? 0 : -1 + 2 * index / (count - 1), 0);

    final indicator = FractionallySizedBox(
      widthFactor: 1 / count,
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.brandAccent,
          borderRadius: BorderRadius.circular(_buttonRadius),
        ),
      ),
    );

    final animation = position;
    return Container(
      height: height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(_buttonRadius + _inset),
      ),
      child: Stack(
        children: [
          if (animation != null)
            AnimatedBuilder(
              animation: animation,
              builder: (context, child) =>
                  Align(alignment: alignmentFor(animation.value), child: child),
              child: indicator,
            )
          else
            AnimatedAlign(
              duration: _duration,
              curve: Curves.easeOutCubic,
              alignment: alignmentFor(selectedIndex.toDouble()),
              child: indicator,
            ),
          Row(
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: _duration,
                          style: theme.textTheme.titleSmall!.copyWith(
                            fontFamily: googleSans,
                            fontWeight: FontWeight.w600,
                            color: i == selectedIndex
                                ? context.onBrandAccent
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                          ),
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
