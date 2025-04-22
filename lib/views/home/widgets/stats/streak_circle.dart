import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/stats/all_stats_model.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/streak_circle_provider.dart';
import 'package:medito/views/home/widgets/stats/streak_circle_controller.dart';
import '../../../../constants/colors/color_constants.dart';
import 'streak_circle_constants.dart';

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
        final hasSeenStreakCircle = ref.watch(streakCircleProvider);

        return statsAsync.when(
          loading: () => _buildShimmer(),
          error: (error, stackTrace) {
            if (statsAsync.hasValue) {
              final stats = statsAsync.value!;
              final isStreakDoneToday =
                  _controller.isStreakDoneToday(stats.audioCompleted);
              final displayValue = _controller.getDisplayValue(stats);
              final progressValue = _controller.getProgressValue(stats);
              final showConsistencyScore =
                  _controller.shouldShowConsistencyScore(stats);

              _controller.updateAnimation(isStreakDoneToday);

              return _buildWithBadge(
                hasSeenStreakCircle,
                AnimatedBuilder(
                  animation: _controller.animationController,
                  builder: (context, child) => _buildStreakCircle(
                      isStreakDoneToday,
                      displayValue,
                      progressValue,
                      showConsistencyScore),
                ),
              );
            } else {
              return _buildErrorState(ref);
            }
          },
          data: (stats) {

            final isPossiblyStillLoading = stats.updated == 0;

            if (isPossiblyStillLoading) {
              Future.microtask(
                  () => ref.read(statsProvider.notifier).refresh());
              return _buildShimmer();
            }

            final isStreakDoneToday =
                _controller.isStreakDoneToday(stats.audioCompleted);
            final displayValue = _controller.getDisplayValue(stats);
            final progressValue = _controller.getProgressValue(stats);
            final showConsistencyScore =
                _controller.shouldShowConsistencyScore(stats);

            _controller.updateAnimation(isStreakDoneToday);

            return _buildWithBadge(
              hasSeenStreakCircle,
              AnimatedBuilder(
                animation: _controller.animationController,
                builder: (context, child) => _buildStreakCircle(
                    isStreakDoneToday,
                    displayValue,
                    progressValue,
                    showConsistencyScore),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWithBadge(AsyncValue<bool> hasSeenStreakCircle, Widget child) {
    return hasSeenStreakCircle.when(
      loading: () => child,
      error: (_, __) => child,
      data: (seen) {
        if (seen) return child;

        return Badge(
          backgroundColor: ColorConstants.amber,
          smallSize: 8,
          alignment: Alignment.topLeft,
          child: GestureDetector(
            onTap: () {
              ref.read(streakCircleProvider.notifier).markAsSeen();
              widget.onTap();
            },
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildStreakCircle(bool isStreakDoneToday, String displayValue,
      double progressValue, bool showConsistencyScore) {
    return Container(
      decoration: isStreakDoneToday
          ? BoxDecoration(
              gradient: SweepGradient(
                colors: [
                  ColorConstants.lightPurple.withOpacity(0.2),
                  ColorConstants.lightPurple.withOpacity(0.35),
                  ColorConstants.lightPurple.withOpacity(1),
                  ColorConstants.lightPurple.withOpacity(0.3),
                  ColorConstants.lightPurple.withOpacity(0.25),
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
          child: InkWell(
            onTap: widget.onTap,
            borderRadius:
                BorderRadius.circular(StreakCircleConstants.borderRadius),
            child: Ink(
              decoration: BoxDecoration(
                color: ColorConstants.onyx,
                borderRadius:
                    BorderRadius.circular(StreakCircleConstants.borderRadius),
              ),
              child: Padding(
                padding: StreakCircleConstants.padding,
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
                          backgroundColor:
                              ColorConstants.white.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isStreakDoneToday
                                ? ColorConstants.lightPurple
                                : ColorConstants.white,
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
                            HugeIcon(
                              icon: HugeIcons.solidRoundedFire,
                              size: StreakCircleConstants.iconSize,
                              color: Colors.white,
                            ),
                          HugeIcon(
                            icon: HugeIcons.solidRoundedFire,
                            color: isStreakDoneToday
                                ? ColorConstants.lightPurple
                                : ColorConstants.white,
                            size: StreakCircleConstants.innerIconSize,
                          ),
                        ],
                      ),
                    const SizedBox(width: 8),
                    Text(
                      displayValue + (showConsistencyScore ? '%' : ''),
                      style: TextStyle(
                        color: ColorConstants.white,
                        fontSize: StreakCircleConstants.fontSize,
                        fontWeight: isStreakDoneToday
                            ? FontWeight.bold
                            : FontWeight.w400,
                        fontFamily: dmMono,
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

  Widget _buildErrorState(WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: ColorConstants.onyx,
        borderRadius: BorderRadius.circular(StreakCircleConstants.borderRadius),
      ),
      child: Padding(
        padding: StreakCircleConstants.padding,
        child: GestureDetector(
          onTap: () => ref.refresh(statsProvider),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedHelpCircle,
            color: ColorConstants.white,
          ),
        ),
      ),
    );
  }
}
