import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:medito/firebase_options.dart';
import 'package:medito/utils/utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/notification/notification_payload_model.dart';
import '../../routes/routes.dart';
import '../../views/bottom_navigation/bottom_navigation_bar_view.dart';

final firebaseMessagingProvider = Provider<FirebaseMessagingHandler>((ref) {
  return FirebaseMessagingHandler();
});

class FirebaseMessagingHandler {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize(BuildContext context, WidgetRef ref) async {
    try {
      _configureFirebaseMessaging(context, ref);
      _initializeLocalNotifications(context, ref);
    } catch (e) {
        if (kDebugMode) {
          print(e);
        }  
    }
  }

  void _configureFirebaseMessaging(
    BuildContext context,
    WidgetRef ref,
  ) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage
        .listen((message) => _handleForegroundMessage(message, context, ref));
    FirebaseMessaging.onMessageOpenedApp
        .listen((message) => _handleMessageOpenedApp(message, context, ref));
  }

  void _initializeLocalNotifications(
    BuildContext context,
    WidgetRef ref,
  ) {
    const initializationSettingsAndroid = AndroidInitializationSettings('logo');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null) {
          final data = json.decode(payload);
          _navigate(context, ref, data);
        }
      },
    );
  }

  void _handleForegroundMessage(
    RemoteMessage message,
    BuildContext context,
    WidgetRef ref,
  ) {
    final snackBar = SnackBar(
      content: Text(message.notification?.body ?? 'New message'),
      action: SnackBarAction(
        label: 'View',
        onPressed: () {
          _navigate(context, ref, message.data);
        },
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _showBackgroundNotification(RemoteMessage message) async {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'firebase_messaging_channel',
      'Firebase Messaging',
      importance: Importance.max,
      priority: Priority.high,
    );
    const platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
      payload: json.encode(message.data),
    );
  }

  void _handleMessageOpenedApp(
    RemoteMessage message,
    BuildContext context,
    WidgetRef ref,
  ) {
    _navigate(context, ref, message.data);
  }

  void _navigate(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> data,
  ) {
    var payload = NotificationPayloadModel.fromJson(data);

    if (payload.type?.isNotNullAndNotEmpty() == true) {
      handleNavigation(
        payload.type,
        [payload.id.toString().getIdFromPath(), payload.path],
        context,
        ref: ref,
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const BottomNavigationBarView(),
        ),
      );
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!Firebase.apps.isNotEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  final handler = FirebaseMessagingHandler();
  await handler._showBackgroundNotification(message);
}
