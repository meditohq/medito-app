import 'dart:convert';
import 'dart:math';

import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';

/// Planned times, never a claim of OS delivery. Carry the snapshot in the
/// payload so a terminated-app tap can still be joined to its scheduling event.
class NotificationTiming {
  NotificationTiming._();

  static Map<String, Object> planned(DateTime when, int notificationId) => {
    'notification_instance_id':
        '${notificationId}_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}',
    'scheduled_at': when.millisecondsSinceEpoch ~/ 1000,
    'scheduled_local_hour': when.hour,
    'scheduled_local_minute': when.minute,
    'scheduled_utc_offset_min': when.timeZoneOffset.inMinutes,
    'scheduled_timezone': when.timeZoneName,
  };

  static Map<String, dynamic> decode(String? payload) {
    try {
      final value = jsonDecode(payload ?? '');
      return value is Map<String, dynamic> ? value : {};
    } catch (_) {
      return {};
    }
  }

  static Map<String, Object> parameters(Map<String, dynamic>? payload) => {
    for (final key in [
      'notification_instance_id',
      'scheduled_at',
      'scheduled_local_hour',
      'scheduled_local_minute',
      'scheduled_utc_offset_min',
      'scheduled_timezone',
      'nearest_reminder_gap_min',
      'reminder_hour',
      'reminder_minute',
    ])
      if (payload?[key] case final Object value
          when value is String || value is int)
        key: value,
  };

  static Map<String, Object> opened(
    Map<String, dynamic>? payload,
    DateTime now,
  ) {
    final plannedAt = payload?['scheduled_at'];
    return {
      ...parameters(payload),
      'opened_local_hour': now.hour,
      'opened_local_minute': now.minute,
      'opened_utc_offset_min': now.timeZoneOffset.inMinutes,
      if (plannedAt is int && now.millisecondsSinceEpoch ~/ 1000 >= plannedAt)
        'seconds_since_scheduled':
            now.millisecondsSinceEpoch ~/ 1000 - plannedAt,
    };
  }

  /// Signed gap: negative = the daily reminder precedes the appeal. Only
  /// inspect actual pending requests, not an assumed daily recurring clock.
  static int? nearestReminderGap(DateTime appeal, Iterable<String?> pending) {
    int? closestSeconds;
    for (final raw in pending) {
      final data = decode(raw);
      final time = data['scheduled_at'];
      if (data['source'] != AnalyticsEventConstants.sourceLocalReminder ||
          time is! int) {
        continue;
      }
      final gap = time - appeal.millisecondsSinceEpoch ~/ 1000;
      if (closestSeconds == null || gap.abs() < closestSeconds.abs()) {
        closestSeconds = gap;
      }
    }
    return closestSeconds == null ? null : (closestSeconds / 60).round();
  }

  /// Analytics failure must not change scheduling/cancellation outcomes.
  static Future<void> log(String event, String? payload) async {
    final data = decode(payload);
    if (data['notification_instance_id'] is! String) return;
    try {
      await FirebaseAnalyticsService().logEvent(
        name: event,
        parameters: {
          ...parameters(data),
          if (data['source'] is String) 'source': data['source'] as String,
          if (data['notification_day'] is int)
            'notification_day': data['notification_day'] as int,
        },
      );
    } catch (_) {
      // Optional measurement cannot prevent a reminder from being delivered.
    }
  }
}
