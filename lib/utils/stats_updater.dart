import 'package:flutter/cupertino.dart';

import '../constants/strings/string_constants.dart';
import '../widgets/snackbar_widget.dart';
import 'call_update_stats.dart';

Future<bool> handleStats(payload, {BuildContext? context}) async {
  try {
    await callUpdateStats(payload);
    showSnackBar(context, StringConstants.statsSuccess);

    return true;
  } catch (e, _) {
    showSnackBar(context, StringConstants.statsError);

    return false;
  }
}