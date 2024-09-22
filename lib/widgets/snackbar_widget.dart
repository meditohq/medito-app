import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';

import '../main.dart';

void showSnackBar(
  BuildContext? context,
  String text, {
  VoidCallback? onActionPressed,
  String? actionLabel,
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
      ],
    ),
    backgroundColor: ColorConstants.white,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  );
  scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
}
