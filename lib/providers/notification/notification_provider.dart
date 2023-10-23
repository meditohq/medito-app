import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/notifications/notifications_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final checkNotificationPermissionProvider = Provider.family<void, BuildContext>((ref, context) {
  Future.delayed(Duration(seconds: 4), () {
    checkNotificationPermission().then((value) {
      var checkPermissionStatusInLocalStorage = ref
          .read(sharedPreferencesProvider)
          .getBool(SharedPreferenceConstants.notificationPermission);
      if (Platform.isAndroid &&
          checkPermissionStatusInLocalStorage == null &&
          value == AuthorizationStatus.denied) {
        context.push(RouteConstants.notificationPermissionPath);
      } else if (Platform.isIOS && value == AuthorizationStatus.notDetermined) {
        context.push(RouteConstants.notificationPermissionPath);
      }
    });
  });
});
