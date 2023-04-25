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
  });
  final void Function()? onPressed;
  final String btnText;
  final Color bgColor;
  final Color textColor;
  final bool isLoading;
  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: isLoading ? null : onPressed,
      disabledColor: bgColor,
      color: bgColor,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            btnText,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isLoading ? bgColor : textColor,
                  fontFamily: ClashDisplay,
                  fontSize: 15,
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
