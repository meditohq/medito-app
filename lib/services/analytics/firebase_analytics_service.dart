import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:medito/services/app_tracking_transparency_service.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/services/analytics/meta_sdk_service.dart';

// Lightweight stand-in so unit tests don't depend on firebase_core.
class _NoopAnalytics {
  Future<void> setConsent({
    bool? analyticsStorageConsentGranted,
    bool? adStorageConsentGranted,
    bool? adUserDataConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
  }) async {}

  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
  }) async {}

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {}

  Future<void> setUserId({String? id}) async {}

  Future<void> setUserProperty({required String name, String? value}) async {}

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
  static const String eventOnboardingNotificationsPreviewShown =
      AnalyticsEventConstants.onboardingNotificationsPreviewShown;
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
  static const String eventOnboardingDonationSkipTap =
      AnalyticsEventConstants.onboardingDonationSkipTap;
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
      if (_runningInTest || isMockMode) {
        _analytics = _NoopAnalytics() as dynamic; // cast to satisfy type
      } else {
        _analytics = FirebaseAnalytics.instance;
      }

      // For iOS, request App Tracking Transparency authorization if requested.
      // IMPORTANT: ATT governs cross-app *advertising* tracking only (IDFA,
      // ad attribution). First-party product analytics does NOT require ATT,
      // so a denial must not disable analytics — it only revokes ad consent
      // below. Previously we flipped analyticsFirebaseEnabled=false here, which
      // blinded us to the ~80% of iOS users who decline tracking.
      TrackingStatus attStatus = TrackingStatus.notSupported;
      if (Platform.isIOS && requestAttPermissionImmediately) {
        attStatus = await AppTrackingTransparencyService.instance
            .requestTrackingPermission();
      }

      // Product-analytics consent follows the user's in-app setting only.
      final analyticsConsent = await _getConsentPreference();

      // Ad signals additionally require ATT authorization on iOS.
      final adConsent =
          analyticsConsent &&
          (!Platform.isIOS || attStatus == TrackingStatus.authorized);

      // Gate SDK collection on the analytics preference only (not ATT), so
      // events keep flowing for users who decline tracking.
      if (_analytics is FirebaseAnalytics) {
        await (_analytics as FirebaseAnalytics).setAnalyticsCollectionEnabled(
          analyticsConsent,
        );
      }

      // Consent mode v2: analytics_storage tracks product-analytics consent;
      // the ad_* signals are additionally gated by ATT.
      await setConsent(
        analyticsStorageConsentGranted: analyticsConsent,
        adStorageConsentGranted: adConsent,
        adUserDataConsentGranted: adConsent,
        adPersonalizationSignalsConsentGranted: adConsent,
      );

      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Firebase Analytics initialized — analytics consent: $analyticsConsent, ad consent: $adConsent (ATT: $attStatus)',
        );
      }

      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Error initializing Firebase Analytics: $e',
        );
      }
    }
  }

  /// Request App Tracking Transparency permission (for iOS)
  /// Uses the shared ATT service and updates Firebase Analytics based on result
  Future<void> requestIOSTrackingPermission() async {
    if (!Platform.isIOS) {
      return;
    }

    try {
      final status = await AppTrackingTransparencyService.instance
          .requestTrackingPermission();

      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'iOS App Tracking Transparency status: $status',
        );
      }

      // ATT denial revokes only cross-app ad consent; product analytics
      // (analytics_storage) stays on so we don't go blind to ATT-deniers.
      await applyAdConsentFromAttStatus(status);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Error requesting iOS tracking authorization: $e',
        );
      }
    }
  }

  /// Apply ad-related consent (ad_storage / ad_user_data / ad_personalization)
  /// based on the iOS ATT result, WITHOUT touching product-analytics consent.
  /// First-party analytics does not require ATT — only cross-app ad signals do.
  Future<void> applyAdConsentFromAttStatus(TrackingStatus status) async {
    final adGranted = status == TrackingStatus.authorized;
    // analyticsStorageConsentGranted intentionally omitted (null) so the
    // existing product-analytics consent is left unchanged.
    await setConsent(
      adStorageConsentGranted: adGranted,
      adUserDataConsentGranted: adGranted,
      adPersonalizationSignalsConsentGranted: adGranted,
    );
  }

  /// Get the user's saved consent preference or default to true
  Future<bool> _getConsentPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Default to true if not set - analytics is enabled by default
      return prefs.getBool(
            SharedPreferenceConstants.analyticsFirebaseEnabled,
          ) ??
          true;
    } catch (e) {
      // If there's an error, default to true
      return true;
    }
  }

  /// Get the user's analytics consent preference
  Future<bool> isAnalyticsEnabled() async {
    return await _getConsentPreference();
  }

  /// Enable or disable Firebase Analytics collection at the SDK level.
  /// Call this when the user toggles the Firebase analytics setting.
  Future<void> setCollectionEnabled(bool enabled) async {
    try {
      if (_analytics is FirebaseAnalytics) {
        await (_analytics as FirebaseAnalytics).setAnalyticsCollectionEnabled(
          enabled,
        );
      }
      await setConsent(
        analyticsStorageConsentGranted: enabled,
        adStorageConsentGranted: enabled,
        adUserDataConsentGranted: enabled,
        adPersonalizationSignalsConsentGranted: enabled,
      );
      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Analytics collection enabled: $enabled',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Error setting analytics collection enabled: $e',
        );
      }
    }
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
      await prefs.setBool(
        SharedPreferenceConstants.analyticsFirebaseEnabled,
        true,
      );

      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Firebase Analytics consent set to granted for all types',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Error setting Firebase Analytics consent: $e',
        );
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
          SharedPreferenceConstants.analyticsFirebaseEnabled,
          analyticsStorageConsentGranted,
        );
      }

      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Firebase Analytics consent updated:',
        );
        if (analyticsStorageConsentGranted != null) {
          AppLogger.d(
            'FIREBASE_ANALYTICS',
            'Analytics storage: $analyticsStorageConsentGranted',
          );
        }
        if (adStorageConsentGranted != null) {
          AppLogger.d(
            'FIREBASE_ANALYTICS',
            'Ad storage: $adStorageConsentGranted',
          );
        }
        if (adUserDataConsentGranted != null) {
          AppLogger.d(
            'FIREBASE_ANALYTICS',
            'Ad user data: $adUserDataConsentGranted',
          );
        }
        if (adPersonalizationSignalsConsentGranted != null) {
          AppLogger.d(
            'FIREBASE_ANALYTICS',
            'Ad personalization: $adPersonalizationSignalsConsentGranted',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Error setting Firebase Analytics consent: $e',
        );
      }
    }
  }

  /// Log a paywall-dismissed-without-payment event to Firebase + Meta.
  /// Each underlying [logEvent] gates on its own user opt-out preference.
  Future<void> logPaywallDismissedNoPayment({
    String? paywallId,
    String? userId,
    String? paywallSource,
    String? variantId,
    String? experimentId,
  }) async {
    const event = AnalyticsEventConstants.paywallDismissedNoPayment;
    final params = <String, Object>{
      AnalyticsEventConstants.paramPaywallId: paywallId ?? 'unknown',
      AnalyticsEventConstants.paramMeditoUserId: userId ?? 'unknown',
      AnalyticsEventConstants.paramPaywallSource: paywallSource ?? 'unknown',
      AnalyticsEventConstants.paramVariantId: variantId ?? 'unknown',
      AnalyticsEventConstants.paramExperimentId: experimentId ?? 'unknown',
      AnalyticsEventConstants.paramExperimentName: experimentId ?? 'unknown',
    };
    await Future.wait([
      logEvent(name: event, parameters: params),
      MetaSdkService.instance.logEvent(event, params),
    ]);
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
        await _analytics.logEvent(name: name, parameters: parameters);
      } else if (kDebugMode && !analyticsEnabled) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Firebase Analytics disabled by user preference, skipping event: $name',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Error logging event to Firebase Analytics: $e',
        );
      }
    }
  }

  /// If the user has just completed onboarding and not yet performed any
  /// interactive action, logs a single firstActionAfterOnboarding event with
  /// the given target. Subsequent calls are no-ops for this install.
  Future<void> logFirstActionAfterOnboardingIfNeeded(String target) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending =
          prefs.getBool(
            SharedPreferenceConstants.firstActionAfterOnboardingPending,
          ) ??
          false;
      if (!pending) return;

      await prefs.setBool(
        SharedPreferenceConstants.firstActionAfterOnboardingPending,
        false,
      );

      await logEvent(
        name: AnalyticsEventConstants.firstActionAfterOnboarding,
        parameters: {AnalyticsEventConstants.paramTarget: target},
      );
    } catch (_) {
      // Best-effort logging — never throw from analytics.
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
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Error setting user ID in Firebase Analytics: $e',
        );
      }
    }
  }

  /// Clear the user ID from Firebase Analytics
  Future<void> clearUserId() async {
    await setUserId(null);
  }

  /// Set a user property for Firebase Analytics
  Future<void> setUserProperty({required String name, String? value}) async {
    if (_runningInTest) return;
    if (!_initialized) await initialize();

    try {
      // Only set user property if Firebase Analytics is enabled
      final prefs = await SharedPreferences.getInstance();
      final analyticsEnabled =
          prefs.getBool(SharedPreferenceConstants.analyticsFirebaseEnabled) ??
          true;

      if (analyticsEnabled && _analytics != null) {
        await _analytics.setUserProperty(name: name, value: value);
        if (kDebugMode) {
          AppLogger.d(
            'FIREBASE_ANALYTICS',
            'Set user property: $name = $value',
          );
        }
      } else if (kDebugMode && !analyticsEnabled) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Firebase Analytics disabled by user preference, skipping user property: $name',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Error setting user property in Firebase Analytics: $e',
        );
      }
    }
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
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Error resetting Firebase Analytics data: $e',
        );
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
          parameters: {'screen_name': screenName, ...?parameters},
        );

        if (kDebugMode) {
          AppLogger.d(
            'FIREBASE_ANALYTICS',
            'Screen view logged: $screenName${parameters != null ? ' with parameters' : ''}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d(
          'FIREBASE_ANALYTICS',
          'Error logging screen view in Firebase Analytics: $e',
        );
      }
    }
  }

  /// Get stored UTM parameters from SharedPreferences as a map
  /// This returns UTM parameters without removing them, useful for including in events
  static Future<Map<String, String>> getStoredUtmParameters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final utmParams = <String, String>{};

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
        AppLogger.e(
          'FIREBASE_ANALYTICS',
          'Error getting stored UTM parameters',
          e,
        );
      }
      return {};
    }
  }

  /// Apply stored UTM parameters from SharedPreferences to Firebase Analytics user properties
  /// This should be called after user initialization to ensure UTM parameters from
  /// deep links (e.g., from Apple Ads) are properly attributed to the user
  /// Note: UTM parameters are kept in storage so they can be used by other analytics
  /// services (e.g., Meta) for attribution on subsequent events like donations
  /// Re-asserts the `experience_level` user property from the answer persisted
  /// at onboarding.
  ///
  /// It is set once, in the onboarding screen, at the moment the question is
  /// answered — and [setUserProperty] is a no-op while analytics consent is
  /// withheld. Anyone who onboarded during a window where consent was not yet
  /// granted (notably every iOS user before the ATT consent-mode fix) answered
  /// the question, had it written to prefs, and never got the property set. The
  /// answer is therefore invisible on all their subsequent events even though
  /// we know it.
  ///
  /// Re-asserting on launch closes that gap, and costs nothing when the property
  /// is already correct. Mirrors [applyStoredUtmParameters], which exists for
  /// the same reason.
  static Future<void> applyStoredExperienceLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(
        SharedPreferenceConstants.onboardingExperienceLevel,
      );
      if (index == null) return;

      // Index order is fixed by the onboarding question and matches the values
      // logged on onboardingExperienceAnswered.
      const answers = ['never_tried', 'a_little', 'regular_practice'];
      if (index < 0 || index >= answers.length) {
        AppLogger.w(
          'FIREBASE_ANALYTICS',
          'Stored experience level index out of range: $index',
        );
        return;
      }

      final analyticsService = FirebaseAnalyticsService();
      await analyticsService.initialize();
      await analyticsService.setUserProperty(
        name: AnalyticsEventConstants.userPropExperienceLevel,
        value: answers[index],
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'FIREBASE_ANALYTICS',
        'Failed to re-apply stored experience level',
        e,
        stackTrace,
      );
    }
  }

  static Future<void> applyStoredUtmParameters() async {
    try {
      if (_runningInTest) return;

      final prefs = await SharedPreferences.getInstance();
      final analyticsService = FirebaseAnalyticsService();

      // Ensure Firebase Analytics is initialized
      await analyticsService.initialize();

      var appliedCount = 0;

      final utmParams = [
        SharedPreferenceConstants.utmSource,
        SharedPreferenceConstants.utmMedium,
        SharedPreferenceConstants.utmCampaign,
        SharedPreferenceConstants.utmTerm,
        SharedPreferenceConstants.utmContent,
      ];

      for (final paramKey in utmParams) {
        final value = prefs.getString(paramKey);
        if (value != null && value.isNotEmpty) {
          await analyticsService.setUserProperty(name: paramKey, value: value);
          appliedCount++;

          if (kDebugMode) {
            AppLogger.d(
              'FIREBASE_ANALYTICS',
              'Applied stored UTM parameter: $paramKey = $value',
            );
          }
        }
      }

      if (appliedCount > 0) {
        if (kDebugMode) {
          AppLogger.d(
            'FIREBASE_ANALYTICS',
            'Applied $appliedCount stored UTM parameter(s)',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e(
          'FIREBASE_ANALYTICS',
          'Error applying stored UTM parameters',
          e,
        );
      }
    }
  }
}
