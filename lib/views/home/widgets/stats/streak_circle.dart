import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/stats_provider.dart';
import '../../../../constants/colors/color_constants.dart';
import 'package:hugeicons/hugeicons.dart';

class StreakCircle extends ConsumerStatefulWidget {
  final VoidCallback onTap;

  const StreakCircle({
    Key? key,
    required this.onTap,
  }) : super(key: key);

  @override
  ConsumerState<StreakCircle> createState() => _StreakCircleState();
}

class _StreakCircleState extends ConsumerState<StreakCircle>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  static const _kBorderRadius = 30.0;
  static const _kIconSize = 20.0;
  static const _kInnerIconSize = 18.0;
  static const _kFontSize = 16.0;
  static const _kLineHeight = 1.4;
  static const _kPadding = EdgeInsets.fromLTRB(11, 9, 13, 9);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final statsAsync = ref.watch(statsProvider);

        return statsAsync.when(
          loading: () => _buildShimmer(),
          error: (_, __) => _buildErrorState(ref),
          data: (stats) {
            final isStreakDoneToday = _isStreakDoneToday(stats.audioCompleted);
            final streakText = '${stats.streakCurrent}';

            if (isStreakDoneToday && !_animationController.isAnimating) {
              _animationController.repeat();
            } else if (!isStreakDoneToday && _animationController.isAnimating) {
              _animationController.stop();
            }

            return AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) =>
                  _buildStreakCircle(isStreakDoneToday, streakText),
            );
          },
        );
      },
    );
  }

  Widget _buildStreakCircle(bool isStreakDoneToday, String streakText) {
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
                transform:
                    GradientRotation(_animationController.value * 2 * 3.14159),
              ),
              borderRadius: BorderRadius.circular(_kBorderRadius + 1.5),
            )
          : null,
      child: Padding(
        padding: isStreakDoneToday ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(_kBorderRadius),
            child: Ink(
              decoration: BoxDecoration(
                color: ColorConstants.onyx,
                borderRadius: BorderRadius.circular(_kBorderRadius),
              ),
              child: Padding(
                padding: _kPadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isStreakDoneToday)
                          HugeIcon(
                            icon: HugeIcons.solidRoundedFire,
                            size: _kIconSize,
                            color: Colors.white,
                          ),
                        HugeIcon(
                          icon: HugeIcons.solidRoundedFire,
                          color: isStreakDoneToday
                              ? ColorConstants.lightPurple
                              : ColorConstants.white,
                          size: _kInnerIconSize,
                        )
                      ],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      streakText,
                      style: TextStyle(
                        color: ColorConstants.white,
                        fontSize: _kFontSize,
                        fontWeight: isStreakDoneToday
                            ? FontWeight.bold
                            : FontWeight.w400,
                        fontFamily: dmMono,
                        height: _kLineHeight,
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

  bool _isStreakDoneToday(List<LocalAudioCompleted>? audioCompleted) {
    if (audioCompleted == null || audioCompleted.isEmpty) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return audioCompleted.any((audio) {
      final audioDate = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
      return audioDate.isAtSameMomentAs(today) || audioDate.isAfter(today);
    });
  }

  Widget _buildShimmer() {
    return Container(
      decoration: BoxDecoration(
        color: ColorConstants.onyx,
        borderRadius: BorderRadius.circular(_kBorderRadius),
      ),
      child: const Padding(
        padding: _kPadding,
        child: SizedBox(
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
        borderRadius: BorderRadius.circular(_kBorderRadius),
      ),
      child: Padding(
        padding: _kPadding,
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
