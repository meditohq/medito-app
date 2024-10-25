import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthKitManager {
  static final HealthKitManager _instance = HealthKitManager._internal();

  factory HealthKitManager() {
    return _instance;
  }

  HealthKitManager._internal();

  Future<bool?> isHealthSyncPermitted() async {
    return await Health().hasPermissions(
      [HealthDataType.MINDFULNESS],
      permissions: [HealthDataAccess.READ_WRITE],
    );
  }

  Future<bool> requestAuthorization() async {
    return await Health().requestAuthorization(
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
    try {
      var hasPermissions = await isHealthSyncPermitted();

      if (hasPermissions == null || !hasPermissions) {
        hasPermissions = await requestAuthorization();
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
}