// ignore_for_file: use_build_context_synchronously

import 'dart:io' show Platform;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../widgets/dialogs/dialogs.dart';

class PermissionHandler {
  static const String _alarmPermissionDialogKey =
      'alarm_permission_dialog_shown_count';
  static const String _mediaPlaybackPermissionDialogKey =
      'media_playback_permission_dialog_shown_count';
  static const int _maxDialogShowCount = 2;

  static Future<SharedPreferences> _initializeSharedPreferences() async {
    return await SharedPreferences.getInstance();
  }

  static Future<int> _getDialogShownCount(String key) async {
    final prefs = await _initializeSharedPreferences();
    return prefs.getInt(key) ?? 0;
  }

  static Future<void> _incrementDialogShownCount(String key) async {
    final prefs = await _initializeSharedPreferences();
    int count = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, count + 1);
  }

  static Future<bool> requestAlarmPermission(BuildContext context) async {
    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isGranted) {
        return true;
      }

      int dialogShownCount =
          await _getDialogShownCount(_alarmPermissionDialogKey);

      if (dialogShownCount >= _maxDialogShowCount) {
        return false;
      }

      await _incrementDialogShownCount(_alarmPermissionDialogKey);

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => MeditoDialog(
          title: AppLocalizations.of(context)!.reminderPermissions,
          content: SingleChildScrollView(
            child: MeditoDialogBody(
              AppLocalizations.of(context)!.weNeedYourPermissionReminder,
            ),
          ),
          actions: [
            MeditoDialogPrimaryButton(
              label: AppLocalizations.of(context)!.requestPermission,
              onPressed: () => Navigator.of(context).pop(true),
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
      return true;
    }

    return false;
  }

  static Future<bool> requestMediaPlaybackPermission(
      BuildContext context) async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied) {
        return false;
      }

      int dialogShownCount =
          await _getDialogShownCount(_mediaPlaybackPermissionDialogKey);

      if (dialogShownCount >= _maxDialogShowCount) {
        return false;
      }

      await _incrementDialogShownCount(_mediaPlaybackPermissionDialogKey);

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => MeditoDialog(
          title: AppLocalizations.of(context)!.mediaPlaybackPermissions,
          content: SingleChildScrollView(
            child: MeditoDialogBody(
              AppLocalizations.of(context)!.weNeedYourPermissionMedia,
            ),
          ),
          actions: [
            MeditoDialogPrimaryButton(
              label: AppLocalizations.of(context)!.requestPermission,
              onPressed: () => Navigator.of(context).pop(true),
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
      return true;
    }

    return false;
  }
}
