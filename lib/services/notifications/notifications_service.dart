import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/snackbar_widget.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../models/notification/stats_notification_payload.dart';
import '../../utils/call_update_stats.dart';

late final FirebaseMessaging? _messaging;
final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> registerNotification() async {
  try {
    _messaging = FirebaseMessaging.instance;
    await requestGenerateFirebaseToken();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (err) {
    print('Error: $err');
  }
}

Future<String?> requestGenerateFirebaseToken() async {
  try {
    if (_messaging != null) {
      var token = await _messaging?.getToken();

      return token;
    }
  } catch (e) {
    return null;
  }

  return null;
}

Future removeFirebaseToken() async {
  return await _messaging?.deleteToken();
}

Future<AuthorizationStatus?> checkNotificationPermission() async {
  var settings = await _messaging?.getNotificationSettings();

  return settings?.authorizationStatus;
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
  var initializationSettingsAndroid = const AndroidInitializationSettings(
    'logo',
  );
  var initializationSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    onDidReceiveLocalNotification: (id, title, body, payload) =>
        _showNotification(title, body, payload),
  );

  tz.initializeTimeZones();
  final String? timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName!));

  var initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    onDidReceiveNotificationResponse: (res) {
      if (res.payload != null) {
        var payload = json.decode(res.payload!);

        _parseNotificationPayload(payload, context, ref);
      }
    },
  );
}

void _parseNotificationPayload(payload, BuildContext context, WidgetRef ref) {
  try {
    var notificationPayload = NotificationPayloadModel.fromJson(payload);
    _navigate(context, ref, notificationPayload);
  } catch (error) {
    print('Error: $error');
  }

  try {
    StatsNotificationPayload.fromJson(payload);
    handleStats(payload, context);
  } catch (error) {
    print('Error: $error');
  }
}

void handleStats(payload, BuildContext? context) {
  try {
    callUpdateStats(payload);
    showSnackBar(context, StringConstants.statsSuccess);
  } catch (e, _) {
    showSnackBar(context, StringConstants.statsError);
  }
}

void checkInitialMessage(BuildContext context, WidgetRef ref) async {
  try {
    var initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      var notificationPayload =
          NotificationPayloadModel.fromJson(initialMessage.data);
      _navigate(context, ref, notificationPayload);
    }
  } catch (error) {
    print('Error: $error');
  }
}

Future<bool> handleOpeningStatsNotificationsFromBackground(
  context,
  WidgetRef ref,
) async {
  String? selectedNotificationPayload;

  final notificationAppLaunchDetails = !kIsWeb && Platform.isLinux
      ? null
      : await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  if (selectedNotificationPayload.isNotNullAndNotEmpty() &&
      notificationAppLaunchDetails?.didNotificationLaunchApp == true) {
    selectedNotificationPayload =
        notificationAppLaunchDetails!.notificationResponse?.payload;
    _parseNotificationPayload(
      jsonDecode(selectedNotificationPayload!),
      context,
      ref,
    );

    return true;
  }

  return false;
}

void onFirebaseMessageAppOpened(BuildContext context, WidgetRef ref) {
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
      data.type,
      [data.id.toString().getIdFromPath(), data.path],
      context,
      ref: ref,
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
  var iOSPlatformChannelSpecifics =
      const DarwinNotificationDetails(threadIdentifier: threadIdentifier);
  var platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.show(
      Random().nextInt(2147483647),
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  handleStats(notificationResponse.payload, null);
}

const threadIdentifier = 'medito_stats_thread_identifier';
