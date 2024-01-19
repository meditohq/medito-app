import 'dart:convert';
import 'dart:math';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

late final FirebaseMessaging _messaging;
final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> registerNotification() async {
  _messaging = FirebaseMessaging.instance;
  await requestGenerateFirebaseToken();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

Future<String?> requestGenerateFirebaseToken() async {
  try {
    var token = await _messaging.getToken();

    return token;
  } catch (e) {
    return null;
  }
}

Future removeFirebaseToken() async {
  return await _messaging.deleteToken();
}

Future<AuthorizationStatus> checkNotificationPermission() async {
  var settings = await _messaging.getNotificationSettings();

  return settings.authorizationStatus;
}

Future<PermissionStatus> requestPermission() async {
  var settings = await Permission.notification.request();

  return settings;
}

Future<void> initializeNotification(BuildContext context, WidgetRef ref) async {
  await initializeLocalNotification(context, ref);

  // For handling the received notifications
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _showNotification(
      message.notification?.title,
      message.notification?.body,
      json.encode(message.data),
    );
  });
}

Future<void> initializeLocalNotification(
  BuildContext context,
  WidgetRef ref,
) async {
  var initializationSettingsAndroid =
      const AndroidInitializationSettings('notification_icon_push');
  var initializationSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    requestCriticalPermission: false,
    onDidReceiveLocalNotification: (id, title, body, payload) =>
        _showNotification(title, body, payload),
  );

  var initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (res) {
      if (res.payload != null) {
        var payload = json.decode(res.payload!);
        var notificationPayload = NotificationPayloadModel.fromJson(payload);
        _navigate(context, ref, notificationPayload);
      }
    },
  );
}

void checkInitialMessage(BuildContext context, WidgetRef ref) async {
  var initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    var notificationPayload =
        NotificationPayloadModel.fromJson(initialMessage.data);
    _navigate(context, ref, notificationPayload);
  }
}

void onMessageAppOpened(BuildContext context, WidgetRef ref) {
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    var notificationPayload = NotificationPayloadModel.fromJson(message.data);
    _navigate(context, ref, notificationPayload);
  });
}

void _navigate(
  BuildContext context,
  WidgetRef ref,
  NotificationPayloadModel data,
) {
  var goRouterContext = ref.read(goRouterProvider);
  if (data.type.isNotNullAndNotEmpty()) {
    handleNavigation(
      goRouterContext: goRouterContext,
      context: context,
      data.type,
      [data.id.toString().getIdFromPath(), data.path],
    );
  } else {
    goRouterContext.go(RouteConstants.bottomNavbarPath);
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _showNotification(
    message.notification?.title,
    message.notification?.body,
    json.encode(message.data),
  );
}

Future<void> _showNotification(
  String? title,
  String? body,
  String? payload,
) async {
  var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
    'com.google.firebase.messaging.default_notification_icon',
    'your channel name',
    color: ColorConstants.onyx,
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
  );
  var iOSPlatformChannelSpecifics = const DarwinNotificationDetails();
  var platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    Random().nextInt(2147483647),
    title,
    body,
    platformChannelSpecifics,
    payload: payload,
  );
}
