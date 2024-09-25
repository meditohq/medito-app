import 'package:flutter/material.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import '../../../../constants/colors/color_constants.dart';
import '../../../../widgets/medito_huge_icon.dart';

class StreakButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isStreakDoneToday;

  const StreakButton({
    Key? key,
    required this.text,
    required this.onTap,
    this.isStreakDoneToday = false,
  }) : super(key: key);

  static const _kBorderRadius = 30.0;
  static const _kIconSize = 20.0;
  static const _kInnerIconSize = 18.0;
  static const _kFontSize = 16.0;
  static const _kLineHeight = 1.4;

  static const _kPadding = EdgeInsets.fromLTRB(11, 9, 13, 9);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isStreakDoneToday ? ColorConstants.white.withOpacity(0.08) : null,
          border: Border.all(color: ColorConstants.white),
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
                  if(isStreakDoneToday)
                  const MeditoHugeIcon(
                    icon: MeditoHugeIcon.streakIcon,
                    size: _kIconSize,
                    color: Colors.white,
                  ),
                  MeditoHugeIcon(
                    icon: MeditoHugeIcon.streakIcon,
                    size: _kInnerIconSize,
                    color: isStreakDoneToday ? ColorConstants.lightPurple : ColorConstants.white,
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: ColorConstants.white,
                  fontSize: _kFontSize,
                  fontWeight: isStreakDoneToday ? FontWeight.bold : FontWeight.w400,
                  fontFamily: DmMono,
                  height: _kLineHeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
