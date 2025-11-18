import 'package:flutter/foundation.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
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
      // Check if Meta Analytics is enabled by user preference
      final prefs = await SharedPreferences.getInstance();
      final isEnabled =
          prefs.getBool(SharedPreferenceConstants.analyticsMetaEnabled) ?? true;

      if (!isEnabled) {
        if (kDebugMode) {
          AppLogger.d('META',
              'Analytics disabled by user preference, skipping event: $name');
        }
        return;
      }

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

  Future<void> logAppFirstOpenOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'meta_app_first_open_logged';
      if (prefs.getBool(key) == true) return;

      await logEvent(AnalyticsEventConstants.appFirstOpen, {});
      await prefs.setBool(key, true);
    } catch (e, stack) {
      AppLogger.e('META', 'Failed to log app_first_open', e, stack);
    }
  }

  Future<void> logDonationEvents({
    required int revenueCents,
    required String currency,
    required String frequency,
  }) async {
    final props = {
      AnalyticsEventConstants.paramRevenue: revenueCents,
      AnalyticsEventConstants.paramCurrency: currency,
    };

    await logEvent(AnalyticsEventConstants.paywallDonation, props);

    var freqEvent = AnalyticsEventConstants.lifetimeDonation;
    if (frequency == 'monthly') {
      freqEvent = AnalyticsEventConstants.monthlyDonation;
    }
    if (frequency == 'yearly') {
      freqEvent = AnalyticsEventConstants.yearlyDonation;
    }

    await logEvent(freqEvent, props);
  }
}
