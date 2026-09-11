// ignore_for_file: use_build_context_synchronously

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
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/l10n/app_localizations.dart';

import '../../constants/strings/analytics_event_constants.dart';
import '../../models/notification/notification_payload_model.dart';
import '../analytics/firebase_analytics_service.dart';
import '../../routes/routes.dart';
import '../../views/bottom_navigation/bottom_navigation_bar_view.dart';

final firebaseMessagingProvider = Provider<FirebaseMessagingHandler>((ref) {
  return FirebaseMessagingHandler(ref);
});

class FirebaseMessagingHandler {
  final Ref ref;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Track if notifications are initialized
  static bool _isFlutterLocalNotificationsInitialized = false;

  // Create a channel for Android notifications
  static AndroidNotificationChannel? _channel;

  FirebaseMessagingHandler(this.ref);

  Future<void> initialize(BuildContext context, WidgetRef ref) async {
    if (isMockMode) {
      AppLogger.d(
        'FIREBASE_NOTIFICATIONS',
        'Mock mode: skipping Firebase Messaging init',
      );
      return;
    }
    try {
      await _setupFlutterNotifications();
      _configureFirebaseMessaging(context, ref);
      _initializeLocalNotifications(context, ref);

      // Enable headless notification presentation for all platforms, but disable badges
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: false, // Never show badges
            sound: true,
          );

      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_NOTIFICATIONS',
          "Firebase Messaging initialized with foreground presentation enabled (badges disabled)",
        );
      }

      // Request permission explicitly to ensure notifications can show
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: false, // Never request badge permission
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_NOTIFICATIONS',
          "Firebase Messaging permission status: ${settings.authorizationStatus}",
        );
      }

      if (Platform.isIOS) {
        await FirebaseMessaging.instance.setAutoInitEnabled(true);
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_NOTIFICATIONS',
          "Error initializing Firebase Messaging: $e",
        );
      }
    }
  }

  Future<void> _setupFlutterNotifications() async {
    if (_isFlutterLocalNotificationsInitialized) {
      return;
    }

    _channel = const AndroidNotificationChannel(
      'high_importance_channel', // id
      'Medito Notifications', // title
      description: 'Stay up-to-date with the latest from Medito', // description
      importance: Importance.high,
    );

    // Check if the channel already exists (it might have been created in the native code)
    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final channelExists =
        await androidImplementation?.areNotificationsEnabled() ?? false;
    if (!channelExists) {
      // Only create the channel if needed
      await androidImplementation?.createNotificationChannel(_channel!);
    }

    _isFlutterLocalNotificationsInitialized = true;
  }

  void _configureFirebaseMessaging(BuildContext context, WidgetRef ref) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(
      (message) => _handleForegroundMessage(message, context, ref),
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleMessageOpenedApp(message, context, ref),
    );
  }

  void _initializeLocalNotifications(BuildContext context, WidgetRef ref) {
    // Match the Firebase example approach
    const initializationSettingsAndroid = AndroidInitializationSettings('logo');

    // For iOS, initialize with proper settings but disable badges
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false, // Never request badge permission
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final data = _decodePayload(response.payload);
        unawaited(_logNotificationOpen(data));

        // Only deep-link when the payload actually asks for one. The smart
        // reminder series carries no type/path, and routing it through
        // _navigate would push a second home view on top of the current
        // screen — the OS opening the app is already the whole intent.
        if (data != null && data['type'] != null) {
          _navigate(context, ref, data);
        }
      },
    );

    // A reminder fires while the app is terminated, which is the normal case
    // for a 7am notification. That tap never reaches the callback above — it
    // only shows up in the launch details — so without this the taps that
    // matter most were the ones we could not see.
    unawaited(_logColdStartNotificationOpen());

    if (kDebugMode) {
      AppLogger.d('FIREBASE_NOTIFICATIONS', "Local notifications initialized");
    }
  }

  /// Decodes a notification payload without ever throwing. Returns null for a
  /// missing or malformed payload; the open is still logged, as
  /// source='unknown', so a payload regression shows up as a shift in the mix
  /// rather than as silence.
  Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = json.decode(payload);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_NOTIFICATIONS',
          'Error decoding notification payload: $e',
        );
      }
      return null;
    }
  }

  Future<void> _logNotificationOpen(
    Map<String, dynamic>? data, {
    String? sourceOverride,
  }) async {
    final source =
        sourceOverride ??
        (data?['source'] as String?) ??
        (data == null ? 'unknown' : AnalyticsEventConstants.sourcePush);
    final day = data?[AnalyticsEventConstants.paramNotificationDay];

    await FirebaseAnalyticsService().logEvent(
      name: AnalyticsEventConstants.notificationOpened,
      parameters: {
        AnalyticsEventConstants.paramSource: source,
        if (day is int) AnalyticsEventConstants.paramNotificationDay: day,
      },
    );
  }

  Future<void> _logColdStartNotificationOpen() async {
    try {
      final details = await _flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return;

      await _logNotificationOpen(
        _decodePayload(details?.notificationResponse?.payload),
      );
    } catch (e, st) {
      AppLogger.e(
        'FIREBASE_NOTIFICATIONS',
        'Error reading notification launch details: $e',
        st,
      );
    }
  }

  Future<void> _handleForegroundMessage(
    RemoteMessage message,
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Debug log
    if (kDebugMode) {
      AppLogger.d(
        'FIREBASE_NOTIFICATIONS',
        "Received foreground message: ${message.notification?.title} / ${message.notification?.body}",
      );
    }

    // Only show notification manually when the app is in foreground
    // When in background, let the system handle it to avoid duplicates
    if (AppLifecycleState.resumed == WidgetsBinding.instance.lifecycleState) {
      showNotification(message);
    }

    // Still show snackbar for in-app UX, but make sure the context is valid
    if (context.mounted) {
      final localizations = AppLocalizations.of(context)!;
      final snackBar = SnackBar(
        content: Text(
          message.notification?.body ?? localizations.newMessageFallback,
        ),
        action: SnackBarAction(
          label: localizations.viewAction,
          onPressed: () {
            _navigate(context, ref, message.data);
          },
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }

    await ref.read(reminderProvider).clearBadge();
  }

  void showNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null &&
        android != null &&
        _channel != null &&
        !kIsWeb) {
      _flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel!.id,
            _channel!.name,
            channelDescription: _channel!.description,
            icon: 'logo',
            channelShowBadge: false,
          ),
        ),
        payload: json.encode(message.data),
      );
    }
  }

  Future<void> _handleMessageOpenedApp(
    RemoteMessage message,
    BuildContext context,
    WidgetRef ref,
  ) async {
    unawaited(
      _logNotificationOpen(
        message.data,
        sourceOverride: AnalyticsEventConstants.sourcePush,
      ),
    );
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

  Future<void> _clearIOSBadge() async {
    if (Platform.isIOS) {
      // Clear any badge notifications
      const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        badgeNumber: 0,
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      // This approach ensures the badge is cleared
      await _flutterLocalNotificationsPlugin.show(
        id: 0,
        title: null,
        body: null,
        notificationDetails: const NotificationDetails(
          iOS: iOSPlatformChannelSpecifics,
        ),
      );
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed (for background isolates)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase might already be initialized
    if (kDebugMode) {
      AppLogger.d(
        'FIREBASE_NOTIFICATIONS',
        'Error initializing Firebase in background handler: $e',
      );
    }
  }

  // We don't need to manually show notifications in the background
  // The system will handle it based on the AndroidManifest.xml configuration
  // This prevents duplicate notifications

  // Handle iOS badge count
  if (Platform.isIOS) {
    final container = ProviderContainer();
    final handler = container.read(firebaseMessagingProvider);
    await handler._clearIOSBadge();
  }

  AppLogger.d('FIREBASE', 'Handling a background message ${message.messageId}');
}
