import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiktok_events_sdk/tiktok_events_sdk.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:medito/src/tiktok_pigeon.g.dart'; // Import generated Pigeon code

import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/services/app_tracking_transparency_service.dart';
import 'package:medito/utils/logger.dart';

class TikTokAnalyticsService {
  static final TikTokAnalyticsService _instance =
      TikTokAnalyticsService._internal();
  factory TikTokAnalyticsService() => _instance;

  var _initialized = false;

  TikTokAnalyticsService._internal();

  Future<void> initialize({bool requestAttPermissionImmediately = true}) async {
    if (_initialized) return;

    // ---------------------------------------------------------
    // ANDROID: Use Native Pigeon Implementation
    // ---------------------------------------------------------
    if (Platform.isAndroid) {
      try {
        if (kDebugMode) {
          AppLogger.d('TIKTOK', 'Initializing Native Android SDK via Pigeon');
          AppLogger.d('TIKTOK',
              'App ID value: "$tiktokAndroidAppId" (length: ${tiktokAndroidAppId.length})');
        }

        final api = TikTokAndroidApi();
        // Use test event code from config (only set in staging/debug builds)
        final testEventCode = tiktokTestEventCode?.isNotEmpty == true
            ? tiktokTestEventCode
            : null;
        await api.initialize(
            tiktokAndroidAppId,
            tiktokAndroidAppId, // Pass same ID for ttAppId
            kDebugMode,
            testEventCode);

        _initialized = true;

        if (kDebugMode) {
          AppLogger.d('TIKTOK',
              'SDK initialization call completed. Config fetch happens asynchronously.');
          AppLogger.d('TIKTOK',
              'If network is unavailable, config fetch may fail but SDK will retry automatically.');
          AppLogger.d('TIKTOK',
              'Events will be queued and flushed once config fetch succeeds.');
        }
      } catch (e, stack) {
        // If initialization fails due to Pigeon channel error but SDK might still be initialized
        // (e.g., double initialization guard on native side), mark as initialized to prevent retries
        final errorString = e.toString();
        if (errorString.contains('channel-error') ||
            errorString.contains('Unable to establish connection') ||
            (e is PlatformException && e.code == 'channel-error')) {
          AppLogger.w('TIKTOK',
              'Pigeon channel error during initialization - SDK may already be initialized. Marking as initialized.');
          _initialized = true;
        } else {
          AppLogger.e(
              'TIKTOK', 'Error initializing Android TikTok SDK', e, stack);
        }
      }
      return;
    }

    // ---------------------------------------------------------
    // iOS: Keep existing Plugin Implementation
    // ---------------------------------------------------------
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
        AppLogger.d(
            'TIKTOK', 'Initializing iOS Plugin with App ID: $tiktokIosAppId');
      }

      if (Platform.isIOS && requestAttPermissionImmediately) {
        await AppTrackingTransparencyService.instance
            .requestTrackingPermission();
      }

      // Only initialize plugin for iOS (Android uses native Pigeon implementation)
      await TikTokEventsSdk.initSdk(
        androidAppId:
            tiktokAndroidAppId, // Plugin ignores this if we don't call it on Android
        tikTokAndroidId: tiktokAndroidAppId,
        iosAppId: tiktokIosAppId,
        tiktokIosId: tiktokIosAppId,
        isDebugMode: kDebugMode,
        logLevel: kDebugMode ? TikTokLogLevel.debug : TikTokLogLevel.info,
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

      // ---------------------------------------------------------
      // ANDROID: Use Native Pigeon Implementation
      // ---------------------------------------------------------
      if (Platform.isAndroid) {
        await TikTokAndroidApi().logEvent(name, parameters);
        if (kDebugMode)
          AppLogger.d('TIKTOK', 'Logged Native Android event $name');
        return;
      }

      // ---------------------------------------------------------
      // iOS: Use Plugin Implementation
      // ---------------------------------------------------------
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

      // Get stored UTM parameters to include in first open event
      final utmParams = await _getStoredUtmParameters();

      await logEvent(
        name: AnalyticsEventConstants.appFirstOpen,
        parameters: utmParams.isNotEmpty ? utmParams : null,
      );
      await prefs.setBool(key, true);
    } catch (e, stack) {
      AppLogger.e('TIKTOK', 'Failed to log app_first_open', e, stack);
    }
  }

  Future<Map<String, Object>> _getStoredUtmParameters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final utmParams = <String, Object>{};

      final utmParamMap = {
        SharedPreferenceConstants.utmSource: 'utm_source',
        SharedPreferenceConstants.utmMedium: 'utm_medium',
        SharedPreferenceConstants.utmCampaign: 'utm_campaign',
        SharedPreferenceConstants.utmTerm: 'utm_term',
        SharedPreferenceConstants.utmContent: 'utm_content',
      };

      for (final entry in utmParamMap.entries) {
        final value = prefs.getString(entry.key);
        if (value != null && value.isNotEmpty) {
          utmParams[entry.value] = value;
        }
      }

      return utmParams;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.w('TIKTOK', 'Error getting stored UTM parameters: $e');
      }
      return {};
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

    var freqEvent = AnalyticsEventConstants.oneTimeDonation;
    if (frequency == 'monthly') {
      freqEvent = AnalyticsEventConstants.monthlyDonation;
    }
    if (frequency == 'yearly') {
      freqEvent = AnalyticsEventConstants.yearlyDonation;
    }

    await logEvent(name: freqEvent, parameters: props);
  }
}
