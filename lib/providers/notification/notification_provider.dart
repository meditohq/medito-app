import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/notifications/notifications_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_provider.g.dart';

final checkNotificationPermissionProvider =
    Provider.family<void, BuildContext>((ref, context) {
  Future.delayed(Duration(seconds: 4), () {
    var notNowCount = ref.read(getNotificationPermissionCountProvider);
    if (notNowCount < 1) {
      ref.read(notificationPermissionStatusProvider.future).then((value) {
        var isPermissionStatusInLocalStorage = ref
            .read(sharedPreferencesProvider)
            .getBool(SharedPreferenceConstants.notificationPermission);
        if (Platform.isAndroid &&
            isPermissionStatusInLocalStorage == null &&
            value == AuthorizationStatus.denied) {
          context.push(RouteConstants.notificationPermissionPath);
        } else if (Platform.isIOS &&
            value == AuthorizationStatus.notDetermined) {
          context.push(RouteConstants.notificationPermissionPath);
        }
      });
    }
  });
});

@riverpod
Future<void> updateNotificationPermissionCount(
  UpdateNotificationPermissionCountRef ref,
) async {
  var notNowCount = ref.read(getNotificationPermissionCountProvider);
  notNowCount = ++notNowCount;
  await ref.read(sharedPreferencesProvider).setInt(
        SharedPreferenceConstants.notificationPermissionCount,
        notNowCount,
      );
}

@riverpod
Future<AuthorizationStatus> notificationPermissionStatus(
  NotificationPermissionStatusRef _,
) async {
  var status = await checkNotificationPermission();

  return status;
}

@riverpod
int getNotificationPermissionCount(GetNotificationPermissionCountRef ref) {
  return ref.read(sharedPreferencesProvider).getInt(
            SharedPreferenceConstants.notificationPermissionCount,
          ) ??
      0;
}
