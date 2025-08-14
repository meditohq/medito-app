import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/feature_flags_provider.dart';

class StreakFreezeSuggestionWidget extends ConsumerStatefulWidget {
  final LocalAllStats stats;
  final VoidCallback onUseFreeze;

  const StreakFreezeSuggestionWidget({
    super.key,
    required this.stats,
    required this.onUseFreeze,
  });

  @override
  ConsumerState<StreakFreezeSuggestionWidget> createState() =>
      StreakFreezeSuggestionWidgetState();
}

class StreakFreezeSuggestionWidgetState
    extends ConsumerState<StreakFreezeSuggestionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late int _animatingIconIndex = -1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onUseFreeze();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _animateAndUseFreeze(int index) {
    // Check if streak freeze feature is enabled
    final isStreakFreezeEnabled =
        ref.read(featureFlagsProvider).isStreakFreezeEnabled;

    // Don't use streak freeze if feature is disabled
    if (!isStreakFreezeEnabled) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _animatingIconIndex = index;
    });
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    // Check if streak freeze feature is enabled
    final isStreakFreezeEnabled =
        ref.watch(featureFlagsProvider).isStreakFreezeEnabled;

    // Don't show the UI if feature is disabled
    if (!isStreakFreezeEnabled) {
      // Close the bottom sheet on the next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final availableCount = widget.stats.streakFreezes ?? 0;
    final maxCount = widget.stats.maxStreakFreezes ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context)!.streakAtRisk,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: ColorConstants.white,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!
                .streakFreezesAvailableMessage(availableCount.toString()),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: ColorConstants.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < maxCount; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildAnimatedIcon(i, availableCount, theme),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: availableCount > 0
                      ? () {
                          // Find the first available freeze to animate
                          final indexToAnimate = availableCount - 1;
                          if (indexToAnimate >= 0) {
                            _animateAndUseFreeze(indexToAnimate);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorConstants.lightPurple,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        theme.colorScheme.onSurface.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.useStreakFreeze),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAnimatedIcon(int index, int availableCount, ThemeData theme) {
    // If this is not an available freeze or not the animating one
    if (index >= availableCount || index != _animatingIconIndex) {
      return Icon(
        index < availableCount
            ? HugeIcons.solidRoundedSnow
            : HugeIcons.solidSharpCircle,
        size: 50,
        color: index < availableCount
            ? ColorConstants.lightPurple
            : theme.colorScheme.onSurface.withOpacity(0.4),
      );
    }

    // This is the animating icon
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Use a series of animations for a fun effect
        final bounce = CurvedAnimation(
          parent: _animationController,
          curve: Curves.bounceOut,
        );

        // First half: rotate and scale up
        final rotateAnimation =
            Tween<double>(begin: 0, end: 2 * 3.14159).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.0, 0.6, curve: Curves.elasticInOut),
          ),
        );

        // Second half: fade between icons
        final iconTransition = CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.4, 0.8, curve: Curves.easeInOut),
        );

        // Scale animation throughout
        final scaleAnimation = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.3),
            weight: 0.3,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.3, end: 0.8),
            weight: 0.2,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            weight: 0.5,
          ),
        ]).animate(bounce);

        // Color transition
        final colorAnimation = ColorTween(
          begin: ColorConstants.lightPurple,
          end: theme.colorScheme.onSurface.withOpacity(0.4),
        ).animate(iconTransition);

        return Transform.scale(
          scale: scaleAnimation.value,
          child: Transform.rotate(
            angle: rotateAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fading out snow icon
                Opacity(
                  opacity: 1 - iconTransition.value,
                  child: Icon(
                    HugeIcons.solidRoundedSnow,
                    size: 50,
                    color: colorAnimation.value,
                  ),
                ),
                // Fading in circle icon
                Opacity(
                  opacity: iconTransition.value,
                  child: Icon(
                    HugeIcons.solidSharpCircle,
                    size: 50,
                    color: colorAnimation.value,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
