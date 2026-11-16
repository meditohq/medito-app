import 'dart:async';

import 'package:flutter/services.dart';

class DisableBatteryOptimization {
  static const MethodChannel _channel =
      const MethodChannel('in.jvapps.disable_battery_optimization');

  static Future<bool?> showEnableAutoStartSettings(
      String dialogTitle, String dialogBody) async {
    return await _channel.invokeMethod(
        'showEnableAutoStart', <dynamic>[dialogTitle, dialogBody]);
  }

  static Future<bool?> showDisableManufacturerBatteryOptimizationSettings(
      String dialogTitle, String dialogBody) async {
    return await _channel.invokeMethod('showDisableManBatteryOptimization',
        <dynamic>[dialogTitle, dialogBody]);
  }

  static Future<bool?> showDisableBatteryOptimizationSettings() async {
    return await _channel.invokeMethod('showDisableBatteryOptimization');
  }

  static Future<bool?> showDisableAllOptimizationsSettings(
      String autoStartTitle,
      String autoStartBody,
      String manBatteryTitle,
      String manBatteryBody) async {
    return await _channel.invokeMethod('disableAllOptimizations', <dynamic>[
      autoStartTitle,
      autoStartBody,
      manBatteryTitle,
      manBatteryBody
    ]);
  }

  static Future<bool?> get isAutoStartEnabled async {
    return await _channel.invokeMethod("isAutoStartEnabled");
  }

  static Future<bool?> get isBatteryOptimizationDisabled async {
    return await _channel.invokeMethod("isBatteryOptimizationDisabled");
  }

  static Future<bool?> get isManufacturerBatteryOptimizationDisabled async {
    return await _channel.invokeMethod("isManBatteryOptimizationDisabled");
  }

  static Future<bool?> get isAllBatteryOptimizationDisabled async {
    return await _channel.invokeMethod("isAllOptimizationsDisabled");
  }
}
