import 'package:flutter/foundation.dart';

class DebugOptions {
  static bool get enableDevicePreview {
    if (kReleaseMode) return false;

    return const bool.fromEnvironment(
      'ENABLE_DEVICE_PREVIEW',
      defaultValue: false,
    );
  }
}
