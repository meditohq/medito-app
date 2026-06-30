import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';

import '../scaffold_messenger_key.dart';

void showSnackBar(
  BuildContext? context,
  String text, {
  VoidCallback? onActionPressed,
  String? actionLabel,
  Color backgroundColor = ColorConstants.white,
}) {
  final foregroundColor = backgroundColor.computeLuminance() > 0.5
      ? ColorConstants.greyIsTheNewBlack
      : ColorConstants.white;
  final snackBar = SnackBar(
    content: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            text,
            style: context != null
                ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foregroundColor,
                    fontFamily: dmSans,
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
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
      ],
    ),
    backgroundColor: backgroundColor,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  );
  scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
}
