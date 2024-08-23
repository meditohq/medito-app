import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../constants/strings/string_constants.dart';
import '../widgets/snackbar_widget.dart';
import 'call_update_stats.dart';

Future<bool> handleStats(payload, {BuildContext? context}) async {
  // Show a snackbar indicating that the stats update is in progress
  showSnackBar(context, "Processing stats update...");
  print('Processing stats update');

  var maxRetries = 5;
  var retryCount = 0;
  while (retryCount < maxRetries) {
    try {
      await callUpdateStats(payload);
      // Update the snackbar to indicate success
      showSnackBar(context, StringConstants.statsSuccess);
      print('Stats updated');

      return true;
    } catch (e, s) {
      if (e is SocketException && e.message.contains('Failed host lookup')) {
        retryCount++;
        if (retryCount >= maxRetries) {
          // Update the snackbar to indicate failure
          showSnackBar(context, StringConstants.statsError);
          await Sentry.captureException(e, stackTrace: s);
          print('Stats update failed after $retryCount retries');
          print(e.toString());

          return false;
        } else {
          print('Retrying... ($retryCount/$maxRetries)');
          await Future.delayed(Duration(seconds: 1));
        }
      } else {
        // For non-retryable errors, update the snackbar to indicate failure
        showSnackBar(context, StringConstants.statsError);
        await Sentry.captureException(e, stackTrace: s);
        print('Stats update failed');
        print(e.toString());

        return false;
      }
    }
  }

  return false;
}
