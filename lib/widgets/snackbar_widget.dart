import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

import '../main.dart';

void showSnackBar(BuildContext? context, String text) {
  final snackBar = SnackBar(
    content: Text(
      text,
      style: context != null ? Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: ColorConstants.greyIsTheNewBlack,
            fontFamily: DmSans,
            fontSize: 14,
          ) : null,
    ),
    backgroundColor: ColorConstants.walterWhite,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  );
  scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
}
