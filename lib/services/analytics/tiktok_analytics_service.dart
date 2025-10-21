import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiktok_events_sdk/tiktok_events_sdk.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/utils/logger.dart';

class TikTokAnalyticsService {
  static final TikTokAnalyticsService _instance =
      TikTokAnalyticsService._internal();
  factory TikTokAnalyticsService() => _instance;

  var _initialized = false;

  TikTokAnalyticsService._internal();

  Future<void> initialize({bool requestAttPermissionImmediately = true}) async {
    if (_initialized) return;
    try {
      if (Platform.isIOS && requestAttPermissionImmediately) {
        await _requestIOSTrackingAuthorization();
      }

      await TikTokEventsSdk.initSdk(
        androidAppId: tiktokAndroidAppId,
        tikTokAndroidId: tiktokAndroidAppId,
        iosAppId: tiktokIosAppId,
        tiktokIosId: tiktokIosAppId,
        isDebugMode: kDebugMode,
        logLevel: kDebugMode ? TikTokLogLevel.debug : TikTokLogLevel.none,
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

      _initialized = true;

      if (kDebugMode) {
        AppLogger.d('TIKTOK', 'TikTok SDK initialized');
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

      await logEvent(name: 'app_first_open');
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
      'revenue': revenueCents,
      'currency': currency,
    };

    await logEvent(name: 'paywall_donation', parameters: props);

    var freqEvent = 'lifetime_donation';
    if (frequency == 'monthly') freqEvent = 'monthly_donation';
    if (frequency == 'yearly') freqEvent = 'yearly_donation';

    await logEvent(name: freqEvent, parameters: props);
  }
}
