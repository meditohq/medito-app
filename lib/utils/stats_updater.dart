import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:health/health.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/strings/string_constants.dart';
import '../constants/types/type_constants.dart';
import '../widgets/snackbar_widget.dart';
import 'call_update_stats.dart';

Future<bool> handleStats(
  Map<String, dynamic> payload, {
  BuildContext? context,
}) async {
  showSnackBar(context, StringConstants.processingStatsUpdate);

  var permitted = await isHealthSyncPermitted() == true;
  if (!permitted) {
    await Health().requestAuthorization(
      [HealthDataType.MINDFULNESS],
      permissions: [HealthDataAccess.READ_WRITE],
    );
  }

  if (!await isSessionSynced(payload[TypeConstants.timestampIdKey])) {
    var success = await _updateHealthKit(payload);
    if (success) {
      await markSessionAsSynced(payload[TypeConstants.timestampIdKey]);
    }
  }

  return _attemptBackendUpdate(payload, context);
}

Future<bool> _updateHealthKit(Map<String, dynamic> payload) async {
  final end = DateTime.fromMillisecondsSinceEpoch(
    payload[TypeConstants.timestampIdKey],
  );
  final start = end
      .subtract(Duration(milliseconds: payload[TypeConstants.durationIdKey]));

  return await _writeMindfulnessData(start, end);
}

Future<bool> _attemptBackendUpdate(
  Map<String, dynamic> payload,
  BuildContext? context,
) async {
  var maxRetries = 5;
  var retryCount = 0;

  void showErrorSnackBar() {
    showSnackBar(
      context,
      StringConstants.statsError,
      onActionPressed: () => _attemptBackendUpdate(payload, context),
      actionLabel: StringConstants.tryAgain,
    );
  }

  while (retryCount < maxRetries) {
    try {
      await callUpdateStats(payload);
      showSnackBar(context, StringConstants.statsSuccess);

      return true;
    } catch (e, s) {
      if (e is SocketException && e.message.contains('Failed host lookup')) {
        retryCount++;
        if (retryCount >= maxRetries) {
          showErrorSnackBar();
          await Sentry.captureException(e, stackTrace: s);

          return false;
        } else {
          await Future.delayed(Duration(seconds: 1));
        }
      } else {
        showErrorSnackBar();
        await Sentry.captureException(e, stackTrace: s);

        return false;
      }
    }
  }

  return false;
}

Future<bool?> isHealthSyncPermitted() async {
  return await Health().hasPermissions(
    [HealthDataType.MINDFULNESS],
    permissions: [HealthDataAccess.READ_WRITE],
  );
}

Future<bool> isSessionSynced(int timestamp) async {
  final prefs = await SharedPreferences.getInstance();
  final syncedSessions = prefs.getStringList('syncedSessions') ?? [];

  return syncedSessions.contains(timestamp.toString());
}

Future<void> markSessionAsSynced(int timestamp) async {
  final prefs = await SharedPreferences.getInstance();
  final syncedSessions = prefs.getStringList('syncedSessions') ?? [];
  syncedSessions.add(timestamp.toString());
  await prefs.setStringList('syncedSessions', syncedSessions);
}

Future<bool> _writeMindfulnessData(DateTime start, DateTime end) async {
  try {
    var hasPermissions = await isHealthSyncPermitted();

    if (hasPermissions == null || !hasPermissions) {
      hasPermissions = await Health().requestAuthorization(
        [HealthDataType.MINDFULNESS],
        permissions: [HealthDataAccess.READ_WRITE],
      );
    }

    if (hasPermissions) {
      var success = await Health().writeHealthData(
        value: 0,
        type: HealthDataType.MINDFULNESS,
        startTime: start,
        endTime: end,
        unit: HealthDataUnit.NO_UNIT,
        recordingMethod: RecordingMethod.manual,
      );

      return success;
    } else {
      return false;
    }
  } catch (error) {
    return false;
  }
}
