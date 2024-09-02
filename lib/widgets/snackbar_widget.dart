import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

import '../main.dart';

void showSnackBar(
    BuildContext? context,
    String text, {
      VoidCallback? onActionPressed,
      String? actionLabel,
      TextStyle? actionTextStyle,
      Color? actionColor,
    }) {
  final snackBar = SnackBar(
    content: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            text,
            style: context != null
                ? Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ColorConstants.greyIsTheNewBlack,
              fontFamily: DmSans,
              fontSize: 14,
            )
                : null,
          ),
        ),
        if (onActionPressed != null && actionLabel != null)
          TextButton(
            onPressed: () {
              scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
              onActionPressed();
            },
            child: Text(
              actionLabel,
              style: actionTextStyle ??
                  TextStyle(color: actionColor ?? ColorConstants.lightPurple),
            ),
          ),
      ],
    ),
    backgroundColor: ColorConstants.walterWhite,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  );
  scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
}