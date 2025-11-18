import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';

// Lightweight stand-in so unit tests don't depend on firebase_core.
class _NoopAnalytics {
  Future<void> setConsent({
    bool? analyticsStorageConsentGranted,
    bool? adStorageConsentGranted,
    bool? adUserDataConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
  }) async {}

  Future<void> logEvent(
      {required String name, Map<String, Object?>? parameters}) async {}

  Future<void> logScreenView(
      {required String screenName, String? screenClass}) async {}

  Future<void> setUserId({String? id}) async {}

  Future<void> resetAnalyticsData() async {}
}

/// Service for handling Firebase Analytics initialization and consent settings
class FirebaseAnalyticsService {
  static final FirebaseAnalyticsService _instance =
      FirebaseAnalyticsService._internal();
  factory FirebaseAnalyticsService() => _instance;

  dynamic
      _analytics; // FirebaseAnalytics or _NoopAnalytics - not late final anymore
  bool _initialized = false;

  // Keys and constants
  static const String analyticsEnabledKey = 'analytics_enabled';

  // Analytics event names - These reference shared constants for consistency across all analytics platforms
  // For new code, prefer using AnalyticsEventConstants directly
  static const String eventUnexpectedLogoutRefreshTokenMissing =
      AnalyticsEventConstants.unexpectedLogoutRefreshTokenMissing;
  static const String eventSecureStoragePersistentFailure =
      AnalyticsEventConstants.secureStoragePersistentFailure;
  static const String eventTokenBackupStorageAttempt =
      AnalyticsEventConstants.tokenBackupStorageAttempt;
  static const String eventTokenBackupStorageResult =
      AnalyticsEventConstants.tokenBackupStorageResult;
  static const String eventTokenRetrievedFromBackup =
      AnalyticsEventConstants.tokenRetrievedFromBackup;
  static const String eventTokenBackupAfterErrorAttempt =
      AnalyticsEventConstants.tokenBackupAfterErrorAttempt;
  static const String eventTokenBackupAfterErrorResult =
      AnalyticsEventConstants.tokenBackupAfterErrorResult;
  static const String eventRefreshTokenRetrievalFailed =
      AnalyticsEventConstants.refreshTokenRetrievalFailed;
  static const String eventRefreshTokenReadErrorSharedPreferences =
      AnalyticsEventConstants.refreshTokenReadErrorSharedPreferences;
  static const String eventRefreshTokenReadErrorSecureStorage =
      AnalyticsEventConstants.refreshTokenReadErrorSecureStorage;
  static const String eventEmailAddressSaveFailed =
      AnalyticsEventConstants.emailAddressSaveFailed;
  static const String eventEmailAddressSaveFailed2 =
      AnalyticsEventConstants.emailAddressSaveFailed2;
  static const String eventAuthTokenStorageFailed =
      AnalyticsEventConstants.authTokenStorageFailed;
  static const String eventPostMeditationFeedback =
      AnalyticsEventConstants.postMeditationFeedback;
  static const String eventOnboardingNotificationsPermissionGranted =
      AnalyticsEventConstants.onboardingNotificationsPermissionGranted;
  static const String eventOnboardingNotificationsPermissionDenied =
      AnalyticsEventConstants.onboardingNotificationsPermissionDenied;
  static const String eventOnboardingSplashscreenSignupTap =
      AnalyticsEventConstants.onboardingSplashscreenSignupTap;
  static const String eventOnboardingSplashscreenContinueTap =
      AnalyticsEventConstants.onboardingSplashscreenContinueTap;
  static const String eventOnboardingSignupCompleted =
      AnalyticsEventConstants.onboardingSignupCompleted;
  static const String eventOnboardingReminderSetTap =
      AnalyticsEventConstants.onboardingReminderSetTap;
  static const String eventOnboardingReminderSkipTap =
      AnalyticsEventConstants.onboardingReminderSkipTap;
  static const String eventOnboardingReminderConfirmTap =
      AnalyticsEventConstants.onboardingReminderConfirmTap;
  static const String eventOnboardingReminderCancelTap =
      AnalyticsEventConstants.onboardingReminderCancelTap;
  static const String eventOnboardingDonateNowTap =
      AnalyticsEventConstants.onboardingDonateNowTap;
  static const String eventOnboardingCompleted =
      AnalyticsEventConstants.onboardingCompleted;
  static const String eventOnboardingTrackingPermissionGranted =
      AnalyticsEventConstants.onboardingTrackingPermissionGranted;
  static const String eventOnboardingTrackingPermissionDenied =
      AnalyticsEventConstants.onboardingTrackingPermissionDenied;
  static const String eventPaywallDismissedNoPayment =
      AnalyticsEventConstants.paywallDismissedNoPayment;

  // Paywall source constants - These reference shared constants for consistency across all analytics platforms
  // For new code, prefer using AnalyticsEventConstants directly
  static const String paywallSourceOnboarding =
      AnalyticsEventConstants.paywallSourceOnboarding;
  static const String paywallSourceSettings =
      AnalyticsEventConstants.paywallSourceSettings;
  static const String paywallSourceEndScreen =
      AnalyticsEventConstants.paywallSourceEndScreen;
  static const String paywallSourceAnnouncement =
      AnalyticsEventConstants.paywallSourceAnnouncement;

  // Don't pollute Firebase from unit/widget tests executed via `flutter test`.
  static bool get _runningInTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  FirebaseAnalyticsService._internal() {
    // Don't initialize _analytics here - defer until initialize() is called
    // This prevents [core/no-app] errors when the service is instantiated
    // before Firebase is fully initialized
  }

  /// Initialize the Firebase Analytics service and check for user consent preferences
  /// [requestAttPermissionImmediately] - If true, will request App Tracking Transparency permission right away (iOS only)
  Future<void> initialize({bool requestAttPermissionImmediately = true}) async {
    if (_initialized) return;

    try {
      // Initialize the analytics instance now that Firebase should be ready
      if (_runningInTest) {
        _analytics = _NoopAnalytics() as dynamic; // cast to satisfy type
      } else {
        _analytics = FirebaseAnalytics.instance;
      }

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
        AppLogger.d('FIREBASE_ANALYTICS',
            'Firebase Analytics initialized with consent: $consentGranted');
      }

      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d(
            'FIREBASE_ANALYTICS', 'Error initializing Firebase Analytics: $e');
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
        AppLogger.d('FIREBASE_ANALYTICS',
            'iOS App Tracking Transparency status: $newStatus');
      }

      // If the user denied tracking, also disable Firebase Analytics
      if (newStatus != TrackingStatus.authorized) {
        // Save preference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(analyticsEnabledKey, false);
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('FIREBASE_ANALYTICS',
            'Error requesting iOS tracking authorization: $e');
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

  /// Get the user's analytics consent preference
  Future<bool> isAnalyticsEnabled() async {
    return await _getConsentPreference();
  }

  /// Set all consent flags to true using consent mode v2
  Future<void> setConsentToTrue() async {
    try {
      if (_analytics != null) {
        await _analytics.setConsent(
          analyticsStorageConsentGranted: true,
          adStorageConsentGranted: true,
          adUserDataConsentGranted: true,
          adPersonalizationSignalsConsentGranted: true,
        );
      }

      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(analyticsEnabledKey, true);

      if (kDebugMode) {
        AppLogger.d('FIREBASE_ANALYTICS',
            'Firebase Analytics consent set to granted for all types');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('FIREBASE_ANALYTICS',
            'Error setting Firebase Analytics consent: $e');
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
      if (_analytics != null) {
        await _analytics.setConsent(
          analyticsStorageConsentGranted: analyticsStorageConsentGranted,
          adStorageConsentGranted: adStorageConsentGranted,
          adUserDataConsentGranted: adUserDataConsentGranted,
          adPersonalizationSignalsConsentGranted:
              adPersonalizationSignalsConsentGranted,
        );
      }

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
        AppLogger.d(
            'FIREBASE_ANALYTICS', 'Firebase Analytics consent updated:');
        if (analyticsStorageConsentGranted != null) {
          AppLogger.d('FIREBASE_ANALYTICS',
              'Analytics storage: $analyticsStorageConsentGranted');
        }
        if (adStorageConsentGranted != null) {
          AppLogger.d(
              'FIREBASE_ANALYTICS', 'Ad storage: $adStorageConsentGranted');
        }
        if (adUserDataConsentGranted != null) {
          AppLogger.d(
              'FIREBASE_ANALYTICS', 'Ad user data: $adUserDataConsentGranted');
        }
        if (adPersonalizationSignalsConsentGranted != null) {
          AppLogger.d('FIREBASE_ANALYTICS',
              'Ad personalization: $adPersonalizationSignalsConsentGranted');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('FIREBASE_ANALYTICS',
            'Error setting Firebase Analytics consent: $e');
      }
    }
  }

  /// Log an event to Firebase Analytics
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (_runningInTest) return;
    if (!_initialized) await initialize();

    try {
      // Only log events if analytics consent is granted and _analytics is initialized
      final prefs = await SharedPreferences.getInstance();

      final analyticsEnabled =
          prefs.getBool(SharedPreferenceConstants.analyticsFirebaseEnabled) ??
              true;

      if (analyticsEnabled && _analytics != null) {
        await _analytics.logEvent(
          name: name,
          parameters: parameters,
        );
      } else if (kDebugMode && !analyticsEnabled) {
        AppLogger.d('FIREBASE_ANALYTICS',
            'Firebase Analytics disabled by user preference, skipping event: $name');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('FIREBASE_ANALYTICS',
            'Error logging event to Firebase Analytics: $e');
      }
    }
  }

  /// Set the user ID for Firebase Analytics
  Future<void> setUserId(String? userId) async {
    if (_runningInTest) return;
    if (!_initialized) await initialize();

    try {
      // Only set user ID if Firebase Analytics is enabled
      final prefs = await SharedPreferences.getInstance();
      final analyticsEnabled =
          prefs.getBool(SharedPreferenceConstants.analyticsFirebaseEnabled) ??
              true;

      if (analyticsEnabled && _analytics != null) {
        await _analytics.setUserId(id: userId);
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('FIREBASE_ANALYTICS',
            'Error setting user ID in Firebase Analytics: $e');
      }
    }
  }

  /// Clear the user ID from Firebase Analytics
  Future<void> clearUserId() async {
    await setUserId(null);
  }

  /// Reset all analytics data for this app instance
  Future<void> resetAnalyticsData() async {
    if (_runningInTest) return;
    if (!_initialized) await initialize();

    try {
      if (_analytics != null) {
        await _analytics.resetAnalyticsData();
      }

      if (kDebugMode) {
        AppLogger.d('FIREBASE_ANALYTICS', 'Firebase Analytics data reset');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('FIREBASE_ANALYTICS',
            'Error resetting Firebase Analytics data: $e');
      }
    }
  }

  /// Log a screen view to Firebase Analytics
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {
    if (_runningInTest) return;
    if (!_initialized) await initialize();

    try {
      // Only log screen view if Firebase Analytics is enabled
      final prefs = await SharedPreferences.getInstance();
      final analyticsEnabled =
          prefs.getBool(SharedPreferenceConstants.analyticsFirebaseEnabled) ??
              true;

      if (analyticsEnabled && _analytics != null) {
        await _analytics.logScreenView(
          screenName: screenName,
          screenClass: screenClass ?? 'Flutter',
        );

        // If custom parameters are provided, also log them as a custom event
        if (parameters != null && parameters.isNotEmpty) {
          await _analytics.logEvent(
            name: 'screen_view_with_params',
            parameters: {
              'screen_name': screenName,
              'screen_class': screenClass ?? 'Flutter',
              ...parameters,
            },
          );
        }

        if (kDebugMode) {
          AppLogger.d('FIREBASE_ANALYTICS',
              'Screen view logged: $screenName${parameters != null ? ' with parameters' : ''}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('FIREBASE_ANALYTICS',
            'Error logging screen view in Firebase Analytics: $e');
      }
    }
  }
}
