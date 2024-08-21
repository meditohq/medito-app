import 'dart:io' show Platform;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/strings/string_constants.dart';

class PermissionHandler {
  static Future<bool> requestAlarmPermission(BuildContext context) async {
    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isGranted) {
        return true;
      }

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(StringConstants.reminderPermissions),
          content: Text(StringConstants.weNeedYourPermissionReminder),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(StringConstants.requestPermission),
            ),
          ],
        ),
      );

      if (result == true) {
        final permissionStatus = await Permission.scheduleExactAlarm.request();

        return permissionStatus.isGranted;
      }

      return false;
    } else if (Platform.isIOS) {
      // iOS doesn't require explicit permission for alarms
      return true;
    }

    return false;
  }

  static Future<bool> requestStatsReminderPermission(
    BuildContext context,
  ) async {

    if(Platform.isIOS) return true;

    final status = await Permission.notification.status;
    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(StringConstants.reminderPermissions),
        content: Text(StringConstants.weNeedYourPermissionReminder),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(StringConstants.requestPermission),
          ),
        ],
      ),
    );

    if (result == true) {
      final status = await Permission.notification.request();

      return status.isGranted;
    }

    return false;
  }

  static Future<bool> requestMediaPlaybackPermission(BuildContext context) async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied) {
         return false;
      }

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(StringConstants.mediaPlaybackPermissions),
          content: Text(StringConstants.weNeedYourPermissionMedia),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(StringConstants.requestPermission),
            ),
          ],
        ),
      );

      if (result == true) {
        final newStatus = await Permission.notification.request();

        return newStatus.isGranted;
      }

      return false;
    } else if (Platform.isIOS) {
      // iOS doesn't require explicit permission for media notifications
      return true;
    }

    return false;
  }

}
