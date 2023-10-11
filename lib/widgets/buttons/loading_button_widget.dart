import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class LoadingButtonWidget extends StatelessWidget {
  const LoadingButtonWidget({
    super.key,
    this.onPressed,
    required this.btnText,
    this.bgColor = ColorConstants.greyIsTheNewGrey,
    this.textColor = ColorConstants.walterWhite,
    this.isLoading = false,
    this.elevation = 0,
    this.fontWeight = FontWeight.w700,
    this.fontSize = 14,
  });
  final void Function()? onPressed;
  final String btnText;
  final Color bgColor;
  final Color textColor;
  final bool isLoading;
  final double elevation;
  final FontWeight fontWeight;
  final double fontSize;
  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: isLoading ? null : onPressed,
      elevation: elevation,
      disabledColor: bgColor.withOpacity(0.7),
      color: bgColor,
      splashColor: ColorConstants.transparent,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            btnText,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isLoading ? Colors.transparent : textColor,
                  fontFamily: ClashDisplay,
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                ),
          ),
          if (isLoading)
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textColor,
              ),
            ),
        ],
      ),
    );
  }
}
