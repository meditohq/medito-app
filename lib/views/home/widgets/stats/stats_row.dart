import 'package:flutter/material.dart';

import '../../../../constants/colors/color_constants.dart';

class StatsRow extends StatelessWidget {
  final VoidCallback leftButtonClicked;
  final VoidCallback rightButtonClicked;
  final String leftButtonText;
  final String rightButtonText;
  final IconData leftButtonIcon;
  final IconData rightButtonIcon;
  final Color leftButtonIconColor;
  final Color rightButtonIconColor;

  const StatsRow({
    Key? key,
    required this.leftButtonText,
    required this.rightButtonText,
    required this.leftButtonClicked,
    required this.rightButtonClicked,
    required this.leftButtonIcon,
    required this.rightButtonIcon,
    required this.leftButtonIconColor,
    required this.rightButtonIconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(7.0),
    );

    var leftButtonStyle = TextButton.styleFrom(
      iconColor: leftButtonIconColor,
      backgroundColor: ColorConstants.amsterdamSummer,
      shape: buttonShape,
    );

    var rightButtonStyle = TextButton.styleFrom(
      iconColor: rightButtonIconColor,
      backgroundColor: ColorConstants.amsterdamSummer,
      shape: buttonShape,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: TextButton(
              onPressed: leftButtonClicked,
              style: leftButtonStyle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    leftButtonIcon,
                    size: 20,
                  ),
                  SizedBox(width: 4),
                  Text(
                    leftButtonText,
                    style: TextStyle(
                      color: ColorConstants.walterWhite,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: TextButton(
              onPressed: rightButtonClicked,
              style: rightButtonStyle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    rightButtonIcon,
                    size: 20,
                  ),
                  SizedBox(width: 4),
                  Text(
                    rightButtonText,
                    style: TextStyle(
                      color: ColorConstants.walterWhite,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
    );
  }
}
