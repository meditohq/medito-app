import 'package:flutter/services.dart';

/// Saves mindfulness samples with metadata unsupported by the health plugin.
/// Authorization is handled by HealthKitManager before calling this writer.
class AppleHealthWriter {
  static const channel = MethodChannel('com.medito.app/health');

  Future<bool> writeMindfulnessSession(
    DateTime start,
    DateTime end, {
    String? title,
    String? trackId,
    String? fileId,
  }) async {
    return await channel.invokeMethod<bool>('writeMindfulnessSession', {
          'startEpochMs': start.millisecondsSinceEpoch,
          'endEpochMs': end.millisecondsSinceEpoch,
          'title': title,
          'trackId': trackId,
          'fileId': fileId,
        }) ??
        false;
  }
}
