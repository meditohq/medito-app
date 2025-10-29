import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

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

  // Analytics event names
  static const String eventUnexpectedLogoutRefreshTokenMissing =
      'unexpected_logout_refresh_token_missing';
  static const String eventSecureStoragePersistentFailure =
      'secure_storage_persistent_failure';
  static const String eventTokenBackupStorageAttempt =
      'token_backup_storage_attempt';
  static const String eventTokenBackupStorageResult =
      'token_backup_storage_result';
  static const String eventTokenRetrievedFromBackup =
      'token_retrieved_from_backup';
  static const String eventTokenBackupAfterErrorAttempt =
      'token_backup_after_error_attempt';
  static const String eventTokenBackupAfterErrorResult =
      'token_backup_after_error_result';
  static const String eventRefreshTokenRetrievalFailed =
      'refresh_token_retrieval_failed';
  static const String eventRefreshTokenReadErrorSharedPreferences =
      'refresh_token_read_error_shared_preferences';
  static const String eventRefreshTokenReadErrorSecureStorage =
      'refresh_token_read_error_secure_storage';
  static const String eventEmailAddressSaveFailed = 'email_address_save_failed';
  static const String eventEmailAddressSaveFailed2 =
      'email_address_save_failed2';
  static const String eventAuthTokenStorageFailed = 'auth_token_storage_failed';
  static const String eventPostMeditationFeedback = 'post_meditation_feedback';
  static const String eventOnboardingNotificationsPermissionGranted =
      'onboarding_notifications_permission_granted';
  static const String eventOnboardingNotificationsPermissionDenied =
      'onboarding_notifications_permission_denied';
  static const String eventOnboardingSplashscreenSignupTap =
      'onboarding_splashscreen_signup_tap';
  static const String eventOnboardingSplashscreenContinueTap =
      'onboarding_splashscreen_continue_tap';
  static const String eventOnboardingSignupCompleted =
      'onboarding_signup_completed';
  static const String eventOnboardingReminderSetTap =
      'onboarding_reminder_set_tap';
  static const String eventOnboardingReminderSkipTap =
      'onboarding_reminder_skip_tap';
  static const String eventOnboardingReminderConfirmTap =
      'onboarding_reminder_confirm_tap';
  static const String eventOnboardingReminderCancelTap =
      'onboarding_reminder_cancel_tap';
  static const String eventOnboardingDonateNowTap = 'onboarding_donate_now_tap';
  static const String eventOnboardingCompleted = 'onboarding_completed';
  static const String eventPaywallDismissedNoPayment =
      'paywall_dismissed_no_payment';

  // Paywall source constants
  static const String paywallSourceOnboarding = 'onboarding';
  static const String paywallSourceSettings = 'settings';
  static const String paywallSourceEndScreen = 'end_screen';
  static const String paywallSourceAnnouncement = 'announcement';

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
    if (_runningInTest) return; // Skip in unit tests
    if (kDebugMode) {
      print(
          'Firebase Analytics (DEBUG): Would log event "$name" with parameters: $parameters');
      return; // Skip in debug mode
    }
    if (!_initialized) await initialize();

    try {
      // Only log events if analytics consent is granted and _analytics is initialized
      final prefs = await SharedPreferences.getInstance();
      bool analyticsEnabled = prefs.getBool(analyticsEnabledKey) ?? true;

      if (analyticsEnabled && _analytics != null) {
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

  /// Set the user ID for Firebase Analytics
  Future<void> setUserId(String? userId) async {
    if (_runningInTest) return; 
    if (kDebugMode) {
      print('Firebase Analytics (DEBUG): Would set user ID to: $userId');
      return;
    }
    if (!_initialized) await initialize();

    try {
      // Only set user ID if analytics consent is granted
      final prefs = await SharedPreferences.getInstance();
      bool analyticsEnabled = prefs.getBool(analyticsEnabledKey) ?? true;

      if (analyticsEnabled && _analytics != null) {
        await _analytics.setUserId(id: userId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error setting user ID in Firebase Analytics: $e');
      }
    }
  }

  /// Log a screen view to Firebase Analytics
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {
    if (_runningInTest) return; // Skip in unit tests
    if (kDebugMode) {
      print(
          'Firebase Analytics (DEBUG): Would log screen view "$screenName" with class: ${screenClass ?? 'Flutter'}${parameters != null ? ' and parameters: $parameters' : ''}');
      return; // Skip in debug mode
    }
    if (!_initialized) await initialize();

    try {
      // Only log screen view if analytics consent is granted and _analytics is initialized
      final prefs = await SharedPreferences.getInstance();
      bool analyticsEnabled = prefs.getBool(analyticsEnabledKey) ?? true;

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
          print(
              'Screen view logged: $screenName${parameters != null ? ' with parameters' : ''}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error logging screen view in Firebase Analytics: $e');
      }
    }
  }
}
