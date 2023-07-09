import 'dart:convert';
import 'dart:math';
import 'package:Medito/constants/constants.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

Future<void> requestPermission() async {
  await initialiazeLocalNotification();
  var settings = await _messaging.requestPermission(
    alert: true,
    badge: true,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission');

    // For handling the received notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(
        message.notification?.title,
        message.notification?.body,
        json.encode(message.data),
      );
    });
  } else {
    print('User declined or has not accepted permission');
  }
}

Future<void> initialiazeLocalNotification() async {
  var initializationSettingsAndroid =
      const AndroidInitializationSettings('notification_icon_push');
  var initializationSettingsIOS = DarwinInitializationSettings(
    onDidReceiveLocalNotification: (id, title, body, payload) =>
        _showNotification(title, body, payload),
  );

  var initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onSelect,
  );
}

void onSelect(NotificationResponse? data) async {
  print(data);
}

void checkForInitialMessage() async {
  var initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  //ignore: no-empty-block
  if (initialMessage != null) {
  } else {
    onMessageAppOpened();
  }
}

void onMessageAppOpened() {
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) => {});
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('myBackgroundMessageHandler message: $message');
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
