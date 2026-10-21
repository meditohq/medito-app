import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:medito/utils/logger.dart';
import 'notification_timing.dart';

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

  /// Cancelling an optional campaign must never turn a successful donation
  /// or a settings change into an error if the OS notification service fails.
  static Future<void> cancelSafely(int id) async {
    try {
      // Returning users may cancel the prototype before reminders or push have
      // initialized the shared plugin. Initialization requests no permission.
      await ensureInitialized();
      String? payload;
      try {
        final pending = await plugin.pendingNotificationRequests();
        for (final item in pending) {
          if (item.id == id) payload = item.payload;
        }
      } catch (_) {
        // An unavailable timing snapshot must never block cancellation.
      }
      await cancelTracked(id, payload: payload);
    } catch (e) {
      AppLogger.w('NOTIFICATIONS', 'Could not cancel notification $id: $e');
    }
  }

  static Future<void> cancelTracked(int id, {String? payload}) async {
    await plugin.cancel(id: id);
    await NotificationTiming.log('notification_cancelled', payload);
  }

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
