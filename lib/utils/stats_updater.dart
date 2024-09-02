import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../constants/colors/color_constants.dart';
import '../constants/strings/string_constants.dart';
import '../widgets/snackbar_widget.dart';
import 'call_update_stats.dart';

Future<bool> handleStats(payload, {BuildContext? context}) async {
  showSnackBar(context, StringConstants.processingStatsUpdate);

  var maxRetries = 5;
  var retryCount = 0;

  void showErrorSnackBar() {
    showSnackBar(
      context,
      StringConstants.statsError,
      onActionPressed: () => handleStats(payload, context: context),
      actionLabel: StringConstants.tryAgain,
      actionTextStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      actionColor: ColorConstants.lightPurple,
    );
  }

  Future<bool> attemptUpdate() async {
    while (retryCount < maxRetries) {
      try {
        await callUpdateStats(payload);
        showSnackBar(context, StringConstants.statsSuccess);

        return true;
      } catch (e, s) {
        if (e is SocketException && e.message.contains('Failed host lookup')) {
          retryCount++;
          if (retryCount >= maxRetries) {
            showErrorSnackBar();
            await Sentry.captureException(e, stackTrace: s);

            return false;
          } else {
            await Future.delayed(Duration(seconds: 1));
          }
        } else {
          showErrorSnackBar();
          await Sentry.captureException(e, stackTrace: s);

          return false;
        }
      }
    }

    return false;
  }

  return attemptUpdate();
}
