// ignore_for_file: use_build_context_synchronously

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHandler {
  // Requests permission to show notifications, which is all that smart
  // reminders need. SCHEDULE_EXACT_ALARM is not required because reminders
  // are scheduled with AndroidScheduleMode.inexactAllowWhileIdle.
  static Future<bool> requestNotificationPermission(
      BuildContext context) async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      final result = await Permission.notification.request();
      return result.isGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.notification.status;
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      final result = await Permission.notification.request();
      return result.isGranted;
    }
    return false;
  }
}
