import 'package:flutter/foundation.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/utils/logger.dart';

class MetaSdkService {
  MetaSdkService._();

  static final MetaSdkService instance = MetaSdkService._();
  bool _initialised = false;
  final FacebookAppEvents _events = FacebookAppEvents();

  Future<void> init() async {
    if (_initialised) {
      return;
    }

    AppLogger.d('META', 'Init Facebook App Events (appId=$facebookAppId)');

    // facebook_app_events initialises using platform configs.
    // If consent gating is required, handle it before enabling tracking.

    _initialised = true;
  }

  Future<void> setUserId(String? userId) async {
    try {
      if (userId == null || userId.isEmpty) {
        await _events.clearUserID();
      } else {
        await _events.setUserID(userId);
      }
      AppLogger.d('META', 'Set user ID for FB events: $userId');
    } catch (e) {
      if (kDebugMode) {
        AppLogger.w('META', 'Failed to set FB user ID: $e');
      }
    }
  }

  Future<void> logEvent(String name, Map<String, Object?> params) async {
    try {
      await _events.logEvent(name: name, parameters: params);
      if (kDebugMode) {
        AppLogger.d('META', 'Logged FB event: $name');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.w('META', 'Failed to log FB event $name: $e');
      }
    }
  }
}
