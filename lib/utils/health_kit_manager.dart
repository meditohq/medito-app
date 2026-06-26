import 'dart:io';

import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../src/audio_pigeon.g.dart';

class HealthKitManager {
  static const _authRequestedKey = 'healthAuthRequested';

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

  /// Whether we've already shown the system permission prompt at least once.
  /// Used to avoid nagging the user every session after they decline.
  Future<bool> hasRequestedAuthorization() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authRequestedKey) ?? false;
  }

  /// Requests authorization only if we've never prompted before. Returns the
  /// resulting permission state (false if we'd already asked and won't re-ask).
  /// Use this for automatic/background triggers (player open, session sync).
  /// Explicit user actions (the Settings tile) should call
  /// [requestAuthorization] directly so they can always re-prompt.
  Future<bool> maybeRequestAuthorization() async {
    if (await hasRequestedAuthorization()) return false;
    return requestAuthorization();
  }

  Future<bool> requestAuthorization() async {
    try {
      await _ensureConfigured();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_authRequestedKey, true);
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
          hasPermissions = await maybeRequestAuthorization();
        }
        if (!hasPermissions) return false;
        return await _androidBridge.writeMindfulnessSession(
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        );
      }

      var hasPermissions = await isHealthSyncPermitted();
      if (hasPermissions == null || !hasPermissions) {
        // Always re-request rather than maybeRequestAuthorization() — iOS
        // updates can reset HealthKit permissions without clearing our
        // "already asked" flag, causing silent sync failures.
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
