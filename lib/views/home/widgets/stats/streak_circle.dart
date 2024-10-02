import 'package:flutter/material.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import '../../../../constants/colors/color_constants.dart';
import '../../../../widgets/medito_huge_icon.dart';

class StreakCircle extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool isStreakDoneToday;

  const StreakCircle({
    Key? key,
    required this.text,
    required this.onTap,
    this.isStreakDoneToday = true,
  }) : super(key: key);

  @override
  StreakCircleState createState() => StreakCircleState();
}

class StreakCircleState extends State<StreakCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  static const _kShimmerDuration = Duration(seconds: 8);
  static const _kBorderRadius = 30.0;
  static const _kIconSize = 20.0;
  static const _kInnerIconSize = 18.0;
  static const _kFontSize = 16.0;
  static const _kLineHeight = 1.4;

  static const _kPadding = EdgeInsets.fromLTRB(11, 9, 13, 9);

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: _kShimmerDuration);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: widget.isStreakDoneToday
                  ? LinearGradient(
                      colors: [
                        ColorConstants.lightPurple.withOpacity(0.2),
                        ColorConstants.lightPurple.withOpacity(0.8),
                        Colors.purple.withOpacity(0.6),
                        ColorConstants.lightPurple.withOpacity(0.2),
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                      transform:
                          GradientRotation(_shimmerController.value * 6.28319),
                    )
                  : null,
              borderRadius: BorderRadius.circular(_kBorderRadius),
            ),
            padding: const EdgeInsets.all(1),
            child: Container(
              decoration: BoxDecoration(
                color: ColorConstants.onyx,
                borderRadius: BorderRadius.circular(_kBorderRadius - 2),
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
                        if (widget.isStreakDoneToday)
                          const MeditoHugeIcon(
                            icon: MeditoHugeIcon.streakIcon,
                            size: _kIconSize,
                            color: Colors.white,
                          ),
                        MeditoHugeIcon(
                          icon: MeditoHugeIcon.streakIcon,
                          size: _kInnerIconSize,
                          color: widget.isStreakDoneToday
                              ? ColorConstants.lightPurple
                              : ColorConstants.white,
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.text,
                      style: TextStyle(
                        color: ColorConstants.white,
                        fontSize: _kFontSize,
                        fontWeight: widget.isStreakDoneToday
                            ? FontWeight.bold
                            : FontWeight.w400,
                        fontFamily: DmMono,
                        height: _kLineHeight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
