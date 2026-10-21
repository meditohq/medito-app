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
import 'local_notifications.dart';
import 'notification_timing.dart';
import '../../providers/donation/supporter_appeal_provider.dart';
import '../../providers/donation/supporter_appeal_experiment.dart';
import '../../routes/routes.dart';
import '../../views/bottom_navigation/bottom_navigation_bar_view.dart';

final firebaseMessagingProvider = Provider<FirebaseMessagingHandler>((ref) {
  return FirebaseMessagingHandler(ref);
});

class FirebaseMessagingHandler {
  final Ref ref;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      LocalNotifications.plugin;

  // Track if notifications are initialized
  static bool _isFlutterLocalNotificationsInitialized = false;

  static Future<void>? _openTrackingRegistration;

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
      await registerOpenTracking(ref);

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

    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // Channel creation is idempotent and preserves the user's channel settings.
    await androidImplementation?.createNotificationChannel(_channel!);
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        'medito_supporter_appeal',
        'Support Medito',
        description: 'Occasional messages about Medito and supporting its work',
        importance: Importance.defaultImportance,
      ),
    );

    _isFlutterLocalNotificationsInitialized = true;
  }

  void _configureFirebaseMessaging(WidgetRef ref) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(
      (message) =>
          _handleForegroundMessage(message, navigatorKey.currentContext, ref),
    );
  }

  /// Records and routes notification opens for the life of the app. Runs at
  /// app start: it used to run only from the onboarding reminder screen, so
  /// reminder and push opens from returning users were never seen.
  /// Idempotent; onboarding calls it again harmlessly.
  Future<void> registerOpenTracking(WidgetRef ref) {
    if (isMockMode) return Future.value();
    return _openTrackingRegistration ??= _registerOpenTracking(ref);
  }

  Future<void> _registerOpenTracking(WidgetRef ref) async {
    try {
      LocalNotifications.tapHandler = (response) =>
          _onLocalNotificationTap(response, ref);
      await LocalNotifications.ensureInitialized();
      // Returning users do not revisit onboarding. Receiving messages must be
      // registered at startup too, without requesting notification permission.
      await _setupFlutterNotifications();
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: false,
            sound: true,
          );

      // Finish fallible async setup before attaching listeners. A failed
      // attempt can then retry without leaving duplicate message handlers.
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      _configureFirebaseMessaging(ref);

      // A reminder fires while the app is terminated, which is the normal case
      // for a 7am notification. That tap never reaches the tap handler — it
      // only shows up in the launch details — so without this the taps that
      // matter most were the ones we could not see.
      unawaited(_logColdStartNotificationOpen());

      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _handleMessageOpenedApp(message, ref),
      );

      // Same gap for push: a tap that launches the app from terminated never
      // reaches onMessageOpenedApp. Logged only — routing here would race the
      // splash screen.
      if (initialMessage != null) {
        unawaited(
          _logNotificationOpen(
            initialMessage.data,
            sourceOverride: AnalyticsEventConstants.sourcePush,
          ),
        );
      }
    } catch (e, st) {
      _openTrackingRegistration = null;
      AppLogger.e(
        'FIREBASE_NOTIFICATIONS',
        'Error registering notification open tracking: $e',
        st,
      );
    }
  }

  void _onLocalNotificationTap(NotificationResponse response, WidgetRef ref) {
    final data = _decodePayload(response.payload);
    unawaited(_logNotificationOpen(data));

    // Only deep-link when the payload actually asks for one. The daily
    // reminder series carries no type/path, and routing it through
    // _navigate would push a second home view on top of the current
    // screen — the OS opening the app is already the whole intent.
    final context = navigatorKey.currentContext;
    if (data != null && data['type'] != null && context != null) {
      _navigate(context, ref, data);
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
    try {
      await SupporterAppealRuntime.recordOpen(data);
    } catch (e) {
      AppLogger.w('SUPPORTER_APPEAL', 'Could not record appeal open: $e');
    }
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
        ...NotificationTiming.opened(data, DateTime.now()),
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
    BuildContext? context,
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
    if (message.data['source'] == SupporterAppealExperiment.name) {
      ref.invalidate(supporterAppealProvider);
    }

    // Still show snackbar for in-app UX, but make sure the context is valid
    if (context != null && context.mounted) {
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
            message.data['source'] == SupporterAppealExperiment.name
                ? 'medito_supporter_appeal'
                : _channel!.id,
            message.data['source'] == SupporterAppealExperiment.name
                ? 'Support Medito'
                : _channel!.name,
            channelDescription:
                message.data['source'] == SupporterAppealExperiment.name
                ? 'Occasional messages about Medito and supporting its work'
                : _channel!.description,
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
    WidgetRef ref,
  ) async {
    unawaited(
      _logNotificationOpen(
        message.data,
        sourceOverride: AnalyticsEventConstants.sourcePush,
      ),
    );
    final context = navigatorKey.currentContext;
    if (context != null &&
        message.data['source'] != SupporterAppealExperiment.name) {
      _navigate(context, ref, message.data);
    }
    await ref.read(reminderProvider).clearBadge();
  }

  void _navigate(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> data,
  ) {
    if (data['source'] == SupporterAppealExperiment.name) {
      unawaited(_logNotificationOpen(data));
      return;
    }
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
