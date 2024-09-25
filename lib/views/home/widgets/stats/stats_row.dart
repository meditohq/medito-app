import 'package:flutter/material.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import '../../../../constants/colors/color_constants.dart';
import '../../../../widgets/medito_huge_icon.dart';

class StreakButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const StreakButton({
    Key? key,
    required this.text,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: ColorConstants.white),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 10, right: 8, top: 9, bottom: 10),
              child: MeditoHugeIcon(
                icon: MeditoHugeIcon.streakIcon,
                size: 20,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 12, top: 10, bottom: 10),
              child: Text(
                '140',
                style: TextStyle(
                  color: ColorConstants.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  fontFamily: DmMono,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
