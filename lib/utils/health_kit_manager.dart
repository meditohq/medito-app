import 'dart:io';

import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthKitManager {
  static final HealthKitManager _instance = HealthKitManager._internal();
  final Health health = Health();

  factory HealthKitManager() {
    return _instance;
  }

  HealthKitManager._internal();

  Future<bool?> isHealthSyncPermitted() async {
    if (Platform.isAndroid) {
      return false;
    }
    try {
      return await health.hasPermissions(
        [HealthDataType.MINDFULNESS],
        permissions: [HealthDataAccess.READ_WRITE],
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestAuthorization() async {
    if (Platform.isAndroid) {
      return false;
    }
    return await health.requestAuthorization(
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

  Future<bool> writeMindfulnessData(DateTime start, DateTime end) async {
    if (Platform.isAndroid) {
      return false;
    }
    try {
      var hasPermissions = await isHealthSyncPermitted();

      if (hasPermissions == null || !hasPermissions) {
        hasPermissions = await requestAuthorization();
      }

      if (hasPermissions) {
        var success = await health.writeHealthData(
          value: 0,
          type: HealthDataType.MINDFULNESS,
          startTime: start,
          endTime: end,
          unit: HealthDataUnit.NO_UNIT,
          recordingMethod: RecordingMethod.automatic,
        );

        return success;
      } else {
        return false;
      }
    } catch (error) {
      return false;
    }
  }
}
