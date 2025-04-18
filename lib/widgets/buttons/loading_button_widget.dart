import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';

class LoadingButtonWidget extends StatelessWidget {
  const LoadingButtonWidget({
    super.key,
    this.onPressed,
    required this.btnText,
    this.bgColor = ColorConstants.onyx,
    this.textColor = ColorConstants.white,
    this.isLoading = false,
    this.elevation = 0,
    this.fontWeight = FontWeight.w700,
    this.fontSize = 16,
    this.borderRadius = 8,
  });

  final void Function()? onPressed;
  final String btnText;
  final Color bgColor;
  final Color textColor;
  final bool isLoading;
  final double elevation;
  final FontWeight fontWeight;
  final double fontSize;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        disabledBackgroundColor: bgColor.withOpacity(0.7),
        elevation: elevation,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Text(
                btnText,
                style: TextStyle(
                  color: isLoading ? Colors.transparent : textColor,
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
        ],
      ),
    );
  }
}
