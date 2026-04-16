import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/utils/logger.dart';

class MetaSdkService {
  MetaSdkService._();

  static final MetaSdkService instance = MetaSdkService._();
  bool _initialised = false;
  FacebookAppEvents? _events;
  static const MethodChannel _channel =
      MethodChannel('com.medito.app/facebook');

  Future<void> init() async {
    if (_initialised) {
      return;
    }

    AppLogger.d('META', 'Init Facebook App Events (appId=$facebookAppId)');

    if (facebookAppId.isEmpty) {
      AppLogger.w('META', 'Facebook App ID is empty, skipping SDK init');
      _initialised = true;
      return;
    }

    // Check user preference — skip SDK construction entirely when disabled.
    // This prevents the SDK from making automatic network requests on startup.
    final prefs = await SharedPreferences.getInstance();
    final isEnabled =
        prefs.getBool(SharedPreferenceConstants.analyticsMetaEnabled) ?? true;

    if (!isEnabled) {
      AppLogger.d('META', 'Meta analytics disabled by user, skipping SDK init');
      _initialised = true;
      return;
    }

    _events = FacebookAppEvents();
    _initialised = true;
  }

  /// Enable or disable the Meta SDK at runtime.
  /// When enabling, constructs the SDK if it hasn't been yet.
  /// When disabling, drops the reference so no further events are sent.
  /// Note: the native Facebook SDK may still hold a singleton — a full
  /// disable requires a process restart, but dropping _events prevents
  /// all Dart-side event logging immediately.
  Future<void> setEnabled(bool enabled) async {
    if (enabled && _events == null && facebookAppId.isNotEmpty) {
      _events = FacebookAppEvents();
      _initialised = true;
      AppLogger.d('META', 'Meta SDK enabled at runtime');
    } else if (!enabled) {
      _events = null;
      AppLogger.d('META', 'Meta SDK disabled at runtime');
    }
  }

  /// Update Facebook SDK advertiser tracking enabled flag based on ATT status
  /// This is required for iOS 14+ SKAdNetwork attribution
  /// Call this after ATT permission has been requested
  Future<void> updateTrackingStatus() async {
    if (!Platform.isIOS) {
      return;
    }

    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      final isAuthorized = status == TrackingStatus.authorized;

      // Set advertiser tracking enabled via platform channel
      // This tells Facebook SDK whether it can use IDFA for attribution
      await _channel.invokeMethod('setAdvertiserTrackingEnabled', isAuthorized);

      if (kDebugMode) {
        AppLogger.d('META',
            'Set advertiser tracking enabled: $isAuthorized (ATT status: $status)');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.w('META', 'Failed to set advertiser tracking enabled: $e');
      }
    }
  }

  Future<void> setUserId(String? userId) async {
    try {
      if (userId == null || userId.isEmpty) {
        await _events?.clearUserID();
      } else {
        await _events?.setUserID(userId);
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

      await _events?.logEvent(name: name, parameters: params);
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

      // Get stored UTM parameters to include in first open event
      final utmParams = await _getStoredUtmParameters();

      await logEvent(AnalyticsEventConstants.appFirstOpen, utmParams);
      await prefs.setBool(key, true);
    } catch (e, stack) {
      AppLogger.e('META', 'Failed to log app_first_open', e, stack);
    }
  }

  Future<Map<String, Object?>> _getStoredUtmParameters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final utmParams = <String, Object?>{};

      final utmParamKeys = [
        SharedPreferenceConstants.utmSource,
        SharedPreferenceConstants.utmMedium,
        SharedPreferenceConstants.utmCampaign,
        SharedPreferenceConstants.utmTerm,
        SharedPreferenceConstants.utmContent,
      ];

      for (final paramKey in utmParamKeys) {
        final value = prefs.getString(paramKey);
        if (value != null && value.isNotEmpty) {
          utmParams[paramKey] = value;
        }
      }

      return utmParams;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.w('META', 'Error getting stored UTM parameters: $e');
      }
      return {};
    }
  }

  Future<void> logDonationEvents({
    required int revenueCents,
    required String currency,
    required String frequency,
  }) async {
    // Get stored UTM parameters to include in donation events for attribution
    final utmParams = await _getStoredUtmParameters();

    final props = {
      AnalyticsEventConstants.paramRevenue: revenueCents,
      AnalyticsEventConstants.paramCurrency: currency,
      ...utmParams,
    };

    await logEvent(AnalyticsEventConstants.paywallDonation, props);

    var freqEvent = AnalyticsEventConstants.oneTimeDonation;
    if (frequency == 'monthly') {
      freqEvent = AnalyticsEventConstants.monthlyDonation;
    }
    if (frequency == 'yearly') {
      freqEvent = AnalyticsEventConstants.yearlyDonation;
    }

    await logEvent(freqEvent, props);
  }
}
