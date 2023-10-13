import 'dart:convert';
import 'dart:math';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  var token = await _messaging.getToken();
  print(token);

  return token;
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

Future<void> initializeNotification(WidgetRef ref) async {
  await initializeLocalNotification(ref);

  // For handling the received notifications
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _showNotification(
      message.notification?.title,
      message.notification?.body,
      json.encode(message.data),
    );
  });
}

Future<void> initializeLocalNotification(WidgetRef ref) async {
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
        var notificationPaylaod = NotificationPayloadModel.fromJson(payload);
        _navigate(ref, notificationPaylaod);
      }
    },
  );
}

void checkInitialMessage(WidgetRef ref) async {
  var initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    var notificationPaylaod =
        NotificationPayloadModel.fromJson(initialMessage.data);
    _navigate(ref, notificationPaylaod);
  }
}

void onMessageAppOpened(WidgetRef ref) {
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    var notificationPaylaod = NotificationPayloadModel.fromJson(message.data);
    _navigate(ref, notificationPaylaod);
  });
}

void _navigate(WidgetRef ref, NotificationPayloadModel data) {
  var context = ref.read(goRouterProvider);
  handleNavigation(
    goRouterContext: context,
    data.type,
    [data.id.toString().getIdFromPath(), data.path],
  );
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
