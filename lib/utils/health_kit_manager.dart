import 'dart:io';

import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../src/audio_pigeon.g.dart';

class HealthKitManager {
  static final HealthKitManager _instance = HealthKitManager._internal();
  final Health health = Health();
  final MeditoHealthConnectManager _androidBridge = MeditoHealthConnectManager();
  bool _configured = false;

  factory HealthKitManager() {
    return _instance;
  }

  HealthKitManager._internal();

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    if (Platform.isIOS) {
      await health.configure();
    }
    _configured = true;
  }

  Future<bool> isHealthConnectAvailable() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await _androidBridge.getStatus();
      return status == HealthConnectStatus.available;
    } catch (_) {
      return false;
    }
  }

  Future<void> installHealthConnect() async {
    if (!Platform.isAndroid) return;
    try {
      await _androidBridge.openHealthConnectInstall();
    } catch (_) {}
  }

  Future<bool?> isHealthSyncPermitted() async {
    try {
      await _ensureConfigured();
      if (Platform.isAndroid) {
        if (!await isHealthConnectAvailable()) return false;
        return await _androidBridge.hasMindfulnessPermissions();
      }
      return await health.hasPermissions(
        [HealthDataType.MINDFULNESS],
        permissions: [HealthDataAccess.READ_WRITE],
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestAuthorization() async {
    try {
      await _ensureConfigured();
      if (Platform.isAndroid) {
        if (!await isHealthConnectAvailable()) return false;
        return await _androidBridge.requestMindfulnessPermissions();
      }
      return await health.requestAuthorization(
        [HealthDataType.MINDFULNESS],
        permissions: [HealthDataAccess.READ_WRITE],
      );
    } catch (e) {
      return false;
    }
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
      await _ensureConfigured();

      if (Platform.isAndroid) {
        if (!await isHealthConnectAvailable()) return false;
        var hasPermissions = await _androidBridge.hasMindfulnessPermissions();
        if (!hasPermissions) {
          hasPermissions = await _androidBridge.requestMindfulnessPermissions();
        }
        if (!hasPermissions) return false;
        return await _androidBridge.writeMindfulnessSession(
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        );
      }

      var hasPermissions = await isHealthSyncPermitted();
      if (hasPermissions == null || !hasPermissions) {
        hasPermissions = await requestAuthorization();
      }
      if (!hasPermissions) return false;

      return await health.writeHealthData(
        value: 0,
        type: HealthDataType.MINDFULNESS,
        startTime: start,
        endTime: end,
        unit: HealthDataUnit.NO_UNIT,
        recordingMethod: RecordingMethod.automatic,
      );
    } catch (error) {
      return false;
    }
  }
}
