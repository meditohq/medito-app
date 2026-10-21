import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/firebase_test_helper.dart';

class _Messaging extends FirebaseMessagingPlatform {
  int permissionRequests = 0;
  int presentationConfigurations = 0;
  int initialMessageRequests = 0;

  @override
  FirebaseMessagingPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;

  @override
  Future<void> registerBackgroundMessageHandler(
    BackgroundMessageHandler handler,
  ) async {}

  @override
  Future<RemoteMessage?> getInitialMessage() async {
    initialMessageRequests++;
    if (initialMessageRequests == 1) {
      throw PlatformException(code: 'initial_message_unavailable');
    }
    return null;
  }

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    required bool alert,
    required bool badge,
    required bool sound,
  }) async {
    presentationConfigurations++;
    if (presentationConfigurations == 1) {
      throw PlatformException(code: 'presentation_unavailable');
    }
    expect(alert, isTrue);
    expect(badge, isFalse);
    expect(sound, isTrue);
  }

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    permissionRequests++;
    throw StateError('Startup must not request permission');
  }
}

class _Reminder extends Mock implements ReminderProvider {}

void main() {
  testWidgets(
    'startup retries failures and shares registration without duplicate foreground messages or permission prompts',
    (tester) async {
      await FirebaseTestHelper.initializeFirebaseForTest();
      final messaging = _Messaging();
      FirebaseMessagingPlatform.instance = messaging;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <MethodCall>[];
      var initializationAttempts = 0;
      var campaignChannelAttempts = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'initialize') {
          if (++initializationAttempts == 1) {
            throw PlatformException(code: 'initialization_unavailable');
          }
          return true;
        }
        if (call.method == 'createNotificationChannel' &&
            (call.arguments as Map)['id'] == 'medito_supporter_appeal' &&
            ++campaignChannelAttempts == 1) {
          throw PlatformException(code: 'channel_unavailable');
        }
        return null;
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      });
      final reminder = _Reminder();
      when(() => reminder.clearBadge()).thenAnswer((_) async {});
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reminderProvider.overrideWithValue(reminder)],
          child: Consumer(
            builder: (context, widgetRef, child) {
              ref = widgetRef;
              return MaterialApp(
                navigatorKey: navigatorKey,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(body: SizedBox()),
              );
            },
          ),
        ),
      );
      final handler = ref.read(firebaseMessagingProvider);
      // Failures before and after channel creation must leave registration
      // retryable, including an already cached local-plugin init failure.
      await handler.registerOpenTracking(ref);
      expect(initializationAttempts, 1);
      expect(messaging.presentationConfigurations, 0);
      await handler.registerOpenTracking(ref);
      expect(initializationAttempts, 2);
      expect(campaignChannelAttempts, 1);
      expect(messaging.presentationConfigurations, 0);
      await handler.registerOpenTracking(ref);
      expect(campaignChannelAttempts, 2);
      expect(messaging.presentationConfigurations, 1);
      await handler.registerOpenTracking(ref);
      expect(messaging.initialMessageRequests, 1);
      final registration = handler.registerOpenTracking(ref);
      expect(
        identical(registration, handler.registerOpenTracking(ref)),
        isTrue,
      );
      await registration;
      await handler.registerOpenTracking(ref);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      FirebaseMessagingPlatform.onMessage.add(
        const RemoteMessage(
          data: {'source': 'supporter_appeal_v1', 'appeal_id': 'test-appeal'},
          notification: RemoteNotification(
            title: 'A message from Medito',
            body: 'Open Medito to take a look.',
            android: AndroidNotification(),
          ),
        ),
      );
      await tester.pump();
      expect(messaging.permissionRequests, 0);
      expect(messaging.presentationConfigurations, 3);
      expect(messaging.initialMessageRequests, 2);
      expect(
        calls
            .where((c) => c.method == 'createNotificationChannel')
            .map((c) => (c.arguments as Map)['id']),
        [
          'high_importance_channel',
          'medito_supporter_appeal',
          'high_importance_channel',
          'medito_supporter_appeal',
        ],
      );
      final shown = calls.where((c) => c.method == 'show').toList();
      expect(shown, hasLength(1));
      final arguments = shown.single.arguments as Map;
      expect(arguments['title'], 'A message from Medito');
      expect(
        (arguments['platformSpecifics'] as Map)['channelId'],
        'medito_supporter_appeal',
      );
      expect(arguments['payload'], contains('test-appeal'));
      expect(find.text('Open Medito to take a look.'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'View'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
