import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:medito/firebase_options.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
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
  return FirebaseMessagingHandler(ref);
});

class FirebaseMessagingHandler {
  final Ref ref;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  FirebaseMessagingHandler(this.ref);

  Future<void> initialize(BuildContext context, WidgetRef ref) async {
    try {
      _configureFirebaseMessaging(context, ref);
      _initializeLocalNotifications(context, ref);

      if (Platform.isIOS) {
        await FirebaseMessaging.instance.setAutoInitEnabled(true);
      }
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

  Future<void> _handleForegroundMessage(
    RemoteMessage message,
    BuildContext context,
    WidgetRef ref,
  ) async {
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
    await ref.read(reminderProvider).clearBadge();
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

    if (Platform.isIOS) {
      const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        badgeNumber: 0,
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );
      await _flutterLocalNotificationsPlugin.show(
        0,
        null,
        null,
        const NotificationDetails(iOS: iOSPlatformChannelSpecifics),
      );
    }
  }

  Future<void> _handleMessageOpenedApp(
    RemoteMessage message,
    BuildContext context,
    WidgetRef ref,
  ) async {
    _navigate(context, ref, message.data);
    await ref.read(reminderProvider).clearBadge();
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
  final container = ProviderContainer();
  final handler = container.read(firebaseMessagingProvider);
  await handler._showBackgroundNotification(message);
}
