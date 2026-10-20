import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/notifications/notification_timing.dart';
import 'package:medito/services/reminders/daily_reminders_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);
  test('payload keeps planned instant, local clock and distinct instances', () {
    final when = tz.TZDateTime(
      tz.getLocation('Europe/Berlin'),
      2026,
      10,
      20,
      18,
      30,
    );
    final first =
        jsonDecode(reminderPayload(3, scheduledAt: when, notificationId: 123))
            as Map<String, dynamic>;
    final second =
        jsonDecode(reminderPayload(3, scheduledAt: when, notificationId: 123))
            as Map<String, dynamic>;
    expect(
      first['notification_instance_id'],
      isNot(second['notification_instance_id']),
    );
    expect(first['scheduled_at'], when.toUtc().millisecondsSinceEpoch ~/ 1000);
    expect(first['scheduled_local_hour'], 18);
    expect(first['scheduled_local_minute'], 30);
    expect(first['scheduled_utc_offset_min'], 120);
    expect(first.containsKey('type'), isFalse);
    final opened = NotificationTiming.opened(
      first,
      when.add(const Duration(minutes: 5)),
    );
    expect(
      opened['notification_instance_id'],
      first['notification_instance_id'],
    );
    expect(opened['seconds_since_scheduled'], 300);
    expect(opened['opened_local_hour'], 18);
  });
  test(
    'nearest pending reminder uses actual planned instant and signed gap',
    () {
      final appeal = DateTime.utc(2026, 10, 20, 18, 30);
      String reminder(int minutes) => reminderPayload(
        1,
        scheduledAt: appeal.add(Duration(minutes: minutes)),
        notificationId: minutes,
      );
      expect(
        NotificationTiming.nearestReminderGap(appeal, [
          reminder(-30),
          reminder(1410),
          '{}',
          'bad',
        ]),
        -30,
      );
      expect(
        NotificationTiming.nearestReminderGap(appeal, [
          reminder(15),
          reminder(-30),
        ]),
        15,
      );
      expect(
        NotificationTiming.nearestReminderGap(appeal, [
          reminderPayload(1),
          null,
        ]),
        isNull,
      );
    },
  );
  test(
    'legacy/missing payload does not manufacture planned time or delivery',
    () {
      final opened = NotificationTiming.opened(
        null,
        DateTime.utc(2026, 10, 20),
      );
      expect(opened.containsKey('scheduled_at'), isFalse);
      expect(opened.containsKey('seconds_since_scheduled'), isFalse);
      expect(
        NotificationTiming.opened({
          'scheduled_at': 9999999999,
        }, DateTime.utc(2026)).containsKey('seconds_since_scheduled'),
        isFalse,
      );
      expect(NotificationTiming.decode('bad'), isEmpty);
      expect(NotificationTiming.decode('[]'), isEmpty);
    },
  );
}
