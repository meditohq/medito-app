import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// Service for handling Firebase Analytics initialization and consent settings
class FirebaseAnalyticsService {
  static final FirebaseAnalyticsService _instance =
      FirebaseAnalyticsService._internal();
  factory FirebaseAnalyticsService() => _instance;

  late final FirebaseAnalytics _analytics;
  bool _initialized = false;

  // Key for storing analytics preference
  static const String analyticsEnabledKey = 'analytics_enabled';

  FirebaseAnalyticsService._internal() {
    _analytics = FirebaseAnalytics.instance;
  }

  /// Initialize the Firebase Analytics service and check for user consent preferences
  /// [requestAttPermissionImmediately] - If true, will request App Tracking Transparency permission right away (iOS only)
  Future<void> initialize({bool requestAttPermissionImmediately = true}) async {
    if (_initialized) return;

    try {
      // For iOS, request App Tracking Transparency authorization if requested
      if (Platform.isIOS && requestAttPermissionImmediately) {
        await _requestIOSTrackingAuthorization();
      }

      // Check if user has previously set a preference
      bool consentGranted = await _getConsentPreference();

      // Set consent based on user preference
      await setConsent(
        analyticsStorageConsentGranted: consentGranted,
        adStorageConsentGranted: consentGranted,
        adUserDataConsentGranted: consentGranted,
        adPersonalizationSignalsConsentGranted: consentGranted,
      );

      if (kDebugMode) {
        print('Firebase Analytics initialized with consent: $consentGranted');
      }

      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Firebase Analytics: $e');
      }
    }
  }

  /// Request App Tracking Transparency permission (for iOS)
  Future<void> requestIOSTrackingPermission() async {
    if (Platform.isIOS) {
      await _requestIOSTrackingAuthorization();
    }
  }

  /// Request tracking authorization on iOS using the App Tracking Transparency framework
  Future<void> _requestIOSTrackingAuthorization() async {
    try {
      // Check the current status
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;

      // If not determined, request authorization
      if (status == TrackingStatus.notDetermined) {
        // Wait for dialog to display completely before continuing
        await Future.delayed(const Duration(milliseconds: 200));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }

      // Log the result
      final newStatus =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (kDebugMode) {
        print('iOS App Tracking Transparency status: $newStatus');
      }

      // If the user denied tracking, also disable Firebase Analytics
      if (newStatus != TrackingStatus.authorized) {
        // Save preference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(analyticsEnabledKey, false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting iOS tracking authorization: $e');
      }
    }
  }

  /// Get the user's saved consent preference or default to true
  Future<bool> _getConsentPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Default to true if not set - analytics is enabled by default
      return prefs.getBool(analyticsEnabledKey) ?? true;
    } catch (e) {
      // If there's an error, default to true
      return true;
    }
  }

  /// Set all consent flags to true using consent mode v2
  Future<void> setConsentToTrue() async {
    try {
      await _analytics.setConsent(
        analyticsStorageConsentGranted: true,
        adStorageConsentGranted: true,
        adUserDataConsentGranted: true,
        adPersonalizationSignalsConsentGranted: true,
      );

      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(analyticsEnabledKey, true);

      if (kDebugMode) {
        print('Firebase Analytics consent set to granted for all types');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting Firebase Analytics consent: $e');
      }
    }
  }

  /// Set the consent flags using consent mode v2
  Future<void> setConsent({
    bool? analyticsStorageConsentGranted,
    bool? adStorageConsentGranted,
    bool? adUserDataConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
  }) async {
    try {
      await _analytics.setConsent(
        analyticsStorageConsentGranted: analyticsStorageConsentGranted,
        adStorageConsentGranted: adStorageConsentGranted,
        adUserDataConsentGranted: adUserDataConsentGranted,
        adPersonalizationSignalsConsentGranted:
            adPersonalizationSignalsConsentGranted,
      );

      // If all values are the same, save preference
      if (analyticsStorageConsentGranted != null &&
          adStorageConsentGranted == analyticsStorageConsentGranted &&
          adUserDataConsentGranted == analyticsStorageConsentGranted &&
          adPersonalizationSignalsConsentGranted ==
              analyticsStorageConsentGranted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
            analyticsEnabledKey, analyticsStorageConsentGranted);
      }

      if (kDebugMode) {
        print('Firebase Analytics consent updated:');
        if (analyticsStorageConsentGranted != null) {
          print('Analytics storage: $analyticsStorageConsentGranted');
        }
        if (adStorageConsentGranted != null) {
          print('Ad storage: $adStorageConsentGranted');
        }
        if (adUserDataConsentGranted != null) {
          print('Ad user data: $adUserDataConsentGranted');
        }
        if (adPersonalizationSignalsConsentGranted != null) {
          print('Ad personalization: $adPersonalizationSignalsConsentGranted');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting Firebase Analytics consent: $e');
      }
    }
  }

  /// Log an event to Firebase Analytics
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!_initialized) await initialize();

    try {
      // Only log events if analytics consent is granted
      final prefs = await SharedPreferences.getInstance();
      bool analyticsEnabled = prefs.getBool(analyticsEnabledKey) ?? true;

      if (analyticsEnabled) {
        await _analytics.logEvent(
          name: name,
          parameters: parameters,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error logging event to Firebase Analytics: $e');
      }
    }
  }
}
