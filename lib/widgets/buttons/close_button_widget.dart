import 'package:Medito/constants/colors/color_constants.dart';
import 'package:flutter/material.dart';

class CloseButtonWidget extends StatelessWidget {
  const CloseButtonWidget({
    super.key,
    this.onPressed,
    this.isShowCircle = true,
    this.bgColor = ColorConstants.walterWhite,
    this.icColor = Colors.black,
  });
  final void Function()? onPressed;
  final bool isShowCircle;
  final Color bgColor;
  final Color icColor;
  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: onPressed,
      color: isShowCircle ? bgColor : null,
      height: 40,
      minWidth: 40,
      padding: EdgeInsets.all(0),
      shape: isShowCircle ? CircleBorder() : null,
      child: Icon(
        Icons.close,
        color: icColor,
      ),
    );
  }
}
