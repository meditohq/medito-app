import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiktok_events_sdk/tiktok_events_sdk.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/utils/logger.dart';

class TikTokAnalyticsService {
  static final TikTokAnalyticsService _instance =
      TikTokAnalyticsService._internal();
  factory TikTokAnalyticsService() => _instance;

  var _initialized = false;

  TikTokAnalyticsService._internal();

  Future<void> initialize({bool requestAttPermissionImmediately = true}) async {
    if (_initialized) return;

    // Skip TikTok SDK initialization on iOS simulator (SDK doesn't support simulator)
    if (Platform.isIOS) {
      try {
        final deviceInfo = await DeviceInfoPlugin().iosInfo;
        if (deviceInfo.isPhysicalDevice == false) {
          if (kDebugMode) {
            AppLogger.d(
                'TIKTOK', 'Skipping TikTok SDK initialization on simulator');
          }
          _initialized = true;
          return;
        }
      } catch (e) {
        // If we can't determine device type, continue with initialization
        if (kDebugMode) {
          AppLogger.d('TIKTOK',
              'Could not determine device type, attempting initialization');
        }
      }
    }

    try {
      if (kDebugMode) {
        AppLogger.d('TIKTOK',
            'Initializing with App ID: $tiktokAndroidAppId (Android) / $tiktokIosAppId (iOS)');
      }

      if (Platform.isIOS && requestAttPermissionImmediately) {
        await _requestIOSTrackingAuthorization();
      }

      await TikTokEventsSdk.initSdk(
        androidAppId: tiktokAndroidAppId,
        tikTokAndroidId: tiktokAndroidAppId,
        iosAppId: tiktokIosAppId,
        tiktokIosId: tiktokIosAppId,
        isDebugMode: kDebugMode,
        logLevel: kDebugMode ? TikTokLogLevel.debug : TikTokLogLevel.info,
        androidOptions: TikTokAndroidOptions(
          disableAutoStart: false,
          enableAutoIapTrack: false,
          disableAdvertiserIDCollection: false,
        ),
        iosOptions: TikTokIosOptions(
          disableTracking: false,
          disableAutomaticTracking: false,
          disableSKAdNetworkSupport: false,
        ),
      );

      // Add delay to allow SDK to initialize and fetch config
      if (kDebugMode) {
        await Future.delayed(const Duration(seconds: 2));
      }

      _initialized = true;

      if (kDebugMode) {
        AppLogger.d('TIKTOK',
            'TikTok SDK initialized with test events enabled (debug mode)');
        AppLogger.d('TIKTOK',
            'Note: Config fetch warnings are expected - SDK will retry automatically');
        AppLogger.d('TIKTOK',
            'Events are queued and will flush once config fetch succeeds (may take a few seconds)');
        AppLogger.d('TIKTOK',
            'To see events in Test Events tab: ensure debug mode is enabled and wait for config fetch to complete');
      }
    } catch (e, stack) {
      AppLogger.e('TIKTOK', 'Error initializing TikTok SDK', e, stack);
    }
  }

  Future<void> _requestIOSTrackingAuthorization() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await Future.delayed(const Duration(milliseconds: 200));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e, stack) {
      AppLogger.e('TIKTOK', 'ATT request failed', e, stack);
    }
  }

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      // Check if TikTok Analytics is enabled by user preference
      final prefs = await SharedPreferences.getInstance();
      final isEnabled =
          prefs.getBool(SharedPreferenceConstants.analyticsTiktokEnabled) ??
              true;

      if (!isEnabled) {
        if (kDebugMode) {
          AppLogger.d('TIKTOK',
              'Analytics disabled by user preference, skipping event: $name');
        }
        return;
      }

      if (!_initialized) await initialize();

      await TikTokEventsSdk.logEvent(
        event: TikTokEvent(
          eventName: name,
          properties: EventProperties(
            customProperties:
                parameters?.map((k, v) => MapEntry(k, v)) ?? const {},
          ),
        ),
      );

      if (kDebugMode) {
        AppLogger.d('TIKTOK', 'Logged event $name | $parameters');
        AppLogger.d('TIKTOK',
            'Note: Events may be queued until config fetch completes. Check Test Events tab in TikTok Events Manager.');
      }
    } catch (e, stack) {
      AppLogger.e('TIKTOK', 'Failed to log event $name', e, stack);
    }
  }

  Future<void> logAppFirstOpenOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'tiktok_app_first_open_logged';
      if (prefs.getBool(key) == true) return;

      await logEvent(name: AnalyticsEventConstants.appFirstOpen);
      await prefs.setBool(key, true);
    } catch (e, stack) {
      AppLogger.e('TIKTOK', 'Failed to log app_first_open', e, stack);
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

    await logEvent(
        name: AnalyticsEventConstants.paywallDonation, parameters: props);

    var freqEvent = AnalyticsEventConstants.lifetimeDonation;
    if (frequency == 'monthly') {
      freqEvent = AnalyticsEventConstants.monthlyDonation;
    }
    if (frequency == 'yearly') {
      freqEvent = AnalyticsEventConstants.yearlyDonation;
    }

    await logEvent(name: freqEvent, parameters: props);
  }
}
