import 'package:flutter/material.dart';

class CloseButtonComponent extends StatelessWidget {
  const CloseButtonComponent(
      {super.key,
      this.onPressed,
      this.isShowCircle = true,
      this.bgColor = Colors.black38,
      this.icColor = Colors.white});
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
      padding: EdgeInsets.all(14),
      shape: isShowCircle ? CircleBorder() : null,
      child: Icon(
        Icons.close,
        color: icColor,
      ),
    );
  }
}
