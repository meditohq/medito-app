import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';

import '../scaffold_messenger_key.dart';

/// How long a snackbar stays up. Screen-reader users need far longer than 4s
/// to hear the message, then find and activate an action such as Undo.
Duration snackBarDuration({required bool hasAction}) {
  final screenReader = WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .accessibleNavigation;
  return hasAction && screenReader
      ? const Duration(seconds: 12)
      : const Duration(seconds: 4);
}

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
  final hasAction = onActionPressed != null && actionLabel != null;
  final snackBar = SnackBar(
    duration: snackBarDuration(hasAction: hasAction),
    content: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            text,
            style: context != null
                ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foregroundColor,
                    fontFamily: googleSans,
                    fontSize: 14,
                  )
                : null,
          ),
        ),
        if (hasAction)
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
