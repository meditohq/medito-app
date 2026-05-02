import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/streak_circle_display_provider.dart';
import 'package:medito/providers/settings/settings_providers.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/home/widgets/stats/streak_circle_controller.dart';
import 'package:medito/widgets/medito_icon.dart';
import '../../../../constants/colors/color_constants.dart';
import 'streak_circle_constants.dart';
import 'package:medito/utils/utils.dart';

class StreakCircle extends ConsumerStatefulWidget {
  final VoidCallback onTap;

  const StreakCircle({
    super.key,
    required this.onTap,
  });

  @override
  ConsumerState<StreakCircle> createState() => StreakCircleState();
}

class StreakCircleState extends ConsumerState<StreakCircle>
    with TickerProviderStateMixin {
  late final StreakCircleController _controller;

  @override
  void initState() {
    super.initState();
    _controller = StreakCircleController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final statsAsync = ref.watch(statsProvider);
        final displayTypeAsync = ref.watch(streakCircleDisplayProvider);
        final isZenModeEnabled = ref.watch(zenModeProvider);

        return statsAsync.when(
          loading: () => _buildShimmer(),
          error: (error, stackTrace) {
            if (statsAsync.hasValue) {
              final stats = statsAsync.value!;
              final isStreakDoneToday =
                  _controller.isStreakDoneToday(stats.audioCompleted);

              if (isZenModeEnabled) {
                _controller.updateAnimation(isStreakDoneToday);
                return AnimatedBuilder(
                  animation: _controller.animationController,
                  builder: (context, child) =>
                      _buildZenModeCircle(isStreakDoneToday),
                );
              }

              return displayTypeAsync.when(
                loading: () => _buildShimmer(),
                error: (_, _) {
                  // Fallback to default behavior on error
                  final displayValue = _controller.getDisplayValue(stats);
                  final progressValue = _controller.getProgressValue(stats);
                  final showConsistencyScore =
                      _controller.shouldShowConsistencyScore(stats);

                  _controller.updateAnimation(isStreakDoneToday);

                  return AnimatedBuilder(
                    animation: _controller.animationController,
                    builder: (context, child) => _buildStreakCircle(
                        isStreakDoneToday,
                        displayValue,
                        progressValue,
                        showConsistencyScore),
                  );
                },
                data: (displayType) {
                  final displayValue =
                      _controller.getDisplayValue(stats, displayType);
                  final progressValue =
                      _controller.getProgressValue(stats, displayType);
                  final showConsistencyScore = _controller
                      .shouldShowConsistencyScore(stats, displayType);

                  _controller.updateAnimation(isStreakDoneToday);

                  return AnimatedBuilder(
                    animation: _controller.animationController,
                    builder: (context, child) => _buildStreakCircle(
                        isStreakDoneToday,
                        displayValue,
                        progressValue,
                        showConsistencyScore),
                  );
                },
              );
            } else {
              return _buildErrorState(ref);
            }
          },
          data: (stats) {
            final isStreakDoneToday =
                _controller.isStreakDoneToday(stats.audioCompleted);

            if (isZenModeEnabled) {
              _controller.updateAnimation(isStreakDoneToday);
              return AnimatedBuilder(
                animation: _controller.animationController,
                builder: (context, child) =>
                    _buildZenModeCircle(isStreakDoneToday),
              );
            }

            return displayTypeAsync.when(
              loading: () => _buildShimmer(),
              error: (_, _) {
                // Fallback to default behavior on error
                final displayValue = _controller.getDisplayValue(stats);
                final progressValue = _controller.getProgressValue(stats);
                final showConsistencyScore =
                    _controller.shouldShowConsistencyScore(stats);

                _controller.updateAnimation(isStreakDoneToday);

                return AnimatedBuilder(
                  animation: _controller.animationController,
                  builder: (context, child) => _buildStreakCircle(
                      isStreakDoneToday,
                      displayValue,
                      progressValue,
                      showConsistencyScore),
                );
              },
              data: (displayType) {
                final displayValue =
                    _controller.getDisplayValue(stats, displayType);
                final progressValue =
                    _controller.getProgressValue(stats, displayType);
                final showConsistencyScore =
                    _controller.shouldShowConsistencyScore(stats, displayType);

                _controller.updateAnimation(isStreakDoneToday);

                return AnimatedBuilder(
                  animation: _controller.animationController,
                  builder: (context, child) => _buildStreakCircle(
                      isStreakDoneToday,
                      displayValue,
                      progressValue,
                      showConsistencyScore),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStreakCircle(
    bool isStreakDoneToday,
    String displayValue,
    double progressValue,
    bool showConsistencyScore,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final semanticLabel = showConsistencyScore
        ? '${l10n.consistencyScore}: $displayValue%'
        : '$displayValue ${l10n.dayStreak}';

    return Container(
      decoration: isStreakDoneToday
          ? BoxDecoration(
              gradient: SweepGradient(
                colors: [
                  context.brandPurple.withOpacityValue(0.2),
                  context.brandPurple.withOpacityValue(0.35),
                  context.brandPurple.withOpacityValue(1),
                  context.brandPurple.withOpacityValue(0.3),
                  context.brandPurple.withOpacityValue(0.25),
                ],
                stops: const [0.1, 0.2, 0.5, 0.8, 0.9],
                transform: GradientRotation(
                    _controller.animationController.value * 2 * 3.14159),
              ),
              borderRadius: BorderRadius.circular(
                  StreakCircleConstants.borderRadius + 1.5),
            )
          : null,
      child: Padding(
        padding: isStreakDoneToday ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            label: semanticLabel,
            button: true,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius:
                  BorderRadius.circular(StreakCircleConstants.borderRadius),
              child: Ink(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(
                      StreakCircleConstants.borderRadius),
                ),
                child: Padding(
                  padding: StreakCircleConstants.padding,
                  child: ExcludeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showConsistencyScore)
                          SizedBox(
                            width: StreakCircleConstants.iconSize,
                            height: StreakCircleConstants.iconSize,
                            child: CircularProgressIndicator(
                              value: progressValue,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacityValue(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isStreakDoneToday
                                    ? context.brandPurple
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              strokeWidth: 2,
                              strokeCap: StrokeCap.round,
                            ),
                          )
                        else
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              if (isStreakDoneToday)
                                MeditoIcon(
                                  assetName: MeditoIcons.fire,
                                  size: StreakCircleConstants.iconSize,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              MeditoIcon(
                                assetName: MeditoIcons.fire,
                                color: isStreakDoneToday
                                    ? context.brandPurple
                                    : Theme.of(context).colorScheme.onSurface,
                                size: StreakCircleConstants.innerIconSize,
                              ),
                            ],
                          ),
                        const SizedBox(width: 8),
                        Text(
                          displayValue + (showConsistencyScore ? '%' : ''),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: StreakCircleConstants.fontSize,
                            fontWeight: isStreakDoneToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontFamily: dmSans,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                            letterSpacing: -0.2,
                            height: StreakCircleConstants.lineHeight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      decoration: BoxDecoration(
        color: ColorConstants.onyx,
        borderRadius: BorderRadius.circular(StreakCircleConstants.borderRadius),
      ),
      child: Padding(
        padding: StreakCircleConstants.padding,
        child: const SizedBox(
          width: 24,
          height: 22,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ColorConstants.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZenModeCircle(bool isStreakDoneToday) {
    return Container(
      decoration: isStreakDoneToday
          ? BoxDecoration(
              gradient: SweepGradient(
                colors: [
                  context.brandPurple.withOpacityValue(0.2),
                  context.brandPurple.withOpacityValue(0.35),
                  context.brandPurple.withOpacityValue(1),
                  context.brandPurple.withOpacityValue(0.3),
                  context.brandPurple.withOpacityValue(0.25),
                ],
                stops: const [0.1, 0.2, 0.5, 0.8, 0.9],
                transform: GradientRotation(
                    _controller.animationController.value * 2 * 3.14159),
              ),
              borderRadius: BorderRadius.circular(
                  StreakCircleConstants.borderRadius + 1.5),
            )
          : null,
      child: Padding(
        padding: isStreakDoneToday ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            label: AppLocalizations.of(context)!.viewStreak,
            button: true,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius:
                  BorderRadius.circular(StreakCircleConstants.borderRadius),
              child: Ink(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(
                      StreakCircleConstants.borderRadius),
                ),
                child: Padding(
                  padding: StreakCircleConstants.padding,
                  child: ExcludeSemantics(
                    child: MeditoIcon(
                      assetName: isStreakDoneToday
                          ? MeditoIcons.fire
                          : MeditoIcons.sun,
                      size: StreakCircleConstants.iconSize,
                      color: isStreakDoneToday
                          ? context.brandPurple
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: ColorConstants.onyx,
        borderRadius: BorderRadius.circular(StreakCircleConstants.borderRadius),
      ),
      child: Padding(
        padding: StreakCircleConstants.padding,
        child: Semantics(
          label: AppLocalizations.of(context)!.refresh,
          button: true,
          child: GestureDetector(
            onTap: () => ref.refresh(statsProvider),
            child: ExcludeSemantics(
              child: MeditoIcon(
                assetName: MeditoIcons.help,
                color: ColorConstants.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
