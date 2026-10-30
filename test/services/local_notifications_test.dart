import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:medito/services/notifications/local_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy cancellation retries failed initialization without requesting iOS permission',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      IOSFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'initialize') {
              if (calls.length == 1) {
                throw PlatformException(
                  code: 'transient_initialization_failure',
                );
              }
              return true;
            }
            if (call.method == 'pendingNotificationRequests') return <Object>[];
            return null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await LocalNotifications.cancelSafely(10103000);
      await LocalNotifications.cancelSafely(10103000);
      expect(calls.map((c) => c.method), [
        'initialize',
        'initialize',
        'pendingNotificationRequests',
        'cancel',
      ]);
      final settings = calls.first.arguments as Map;
      expect(settings['requestAlertPermission'], isFalse);
      expect(settings['requestBadgePermission'], isFalse);
      expect(settings['requestSoundPermission'], isFalse);
      expect(calls.last.arguments, 10103000);
    },
  );
}
