import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

/// The one initialisation of flutter_local_notifications, shared by reminders
/// and push.
///
/// The plugin keeps only the tap callback from its most recent initialize()
/// call. Reminders used to initialise it without a callback on every launch,
/// and the push handler only initialised it with one during onboarding, so
/// reminder taps went unrecorded everywhere except in the minutes after
/// onboarding. Everyone now shares this initialisation and taps go to
/// [tapHandler].
class LocalNotifications {
  LocalNotifications._();

  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void>? _initFuture;

  /// Receives taps on notifications while the app is running (foreground or
  /// background). Taps that launch the app from terminated arrive through
  /// `plugin.getNotificationAppLaunchDetails()` instead.
  static void Function(NotificationResponse response)? tapHandler;

  static Future<void> ensureInitialized() => _initFuture ??= _initialize();

  static Future<void> _initialize() async {
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('logo'),
      // Permission is requested explicitly where we want it (onboarding, end
      // screen, settings), never as a side effect of initialising.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) =>
          tapHandler?.call(response),
    );
  }
}
