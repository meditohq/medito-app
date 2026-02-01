// cursor_rule.analyticsstrings.mdc
// Put all analytics event string constants in this file. Add a comment for each event describing the context in which it is used, so that in the future AI and maintainers can accurately translate or update them.

// This file contains all analytics event string constants used for Firebase Analytics, Meta App Events, and other analytics platforms.
// Add a comment for each event describing the context in which it is used, so future AI and maintainers can accurately translate or update them.

class AnalyticsEventConstants {
  // General events
  /// Event name for Firebase Analytics when a product is clicked in the shop section
  static const String productClicked = 'product_clicked';

  /// Event name for when the user changes the order of home screen widgets in CustomiseHomeLayoutScreen
  static const String homeWidgetOrderChanged = 'home_widget_order_changed';

  /// Description for the analytics event when the user changes the order of home screen widgets in CustomiseHomeLayoutScreen
  static const String homeWidgetOrderChangedDesc =
      'User changed the order of home screen widgets';

  // App lifecycle events
  /// Event logged once when the app is first opened
  static const String appFirstOpen = 'app_first_open';

  // Payment and donation events
  /// Event logged when a one-time donation is successfully completed
  static const String donationOnetime = 'donation_onetime';

  /// Event logged when a monthly subscription donation is successfully completed
  static const String donationMonthly = 'donation_monthly';

  /// Event logged when a yearly subscription donation is successfully completed
  static const String donationYearly = 'donation_yearly';

  /// Event logged when a donation is initiated from the paywall (used by Meta)
  static const String paywallDonation = 'paywall_donation';

  /// Event logged for lifetime/one-time donations (used by Meta)
  static const String oneTimeDonation = 'onetime_donation';

  /// Event logged for monthly subscription donations (used by Meta)
  static const String monthlyDonation = 'monthly_donation';

  /// Event logged for yearly subscription donations (used by Meta)
  static const String yearlyDonation = 'yearly_donation';

  /// Event logged when paywall is dismissed without completing a payment
  static const String paywallDismissedNoPayment =
      'paywall_dismissed_no_payment';

  /// Event logged when a payment fails
  static const String paymentFailed = 'payment_failed';

  /// Event logged when a payment is cancelled by the user
  static const String paymentCancelled = 'payment_cancelled';

  // Onboarding events
  /// Event logged when user taps signup on onboarding splashscreen
  static const String onboardingSplashscreenSignupTap =
      'onboarding_splashscreen_signup_tap';

  /// Event logged when user taps continue on onboarding splashscreen
  static const String onboardingSplashscreenContinueTap =
      'onboarding_splashscreen_continue_tap';

  /// Event logged when user completes signup during onboarding
  static const String onboardingSignupCompleted = 'onboarding_signup_completed';

  /// Event logged when user sets a reminder during onboarding
  static const String onboardingReminderSetTap = 'onboarding_reminder_set_tap';

  /// Event logged when user skips reminder setup during onboarding
  static const String onboardingReminderSkipTap =
      'onboarding_reminder_skip_tap';

  /// Event logged when user confirms reminder setup during onboarding
  static const String onboardingReminderConfirmTap =
      'onboarding_reminder_confirm_tap';

  /// Event logged when user cancels reminder setup during onboarding
  static const String onboardingReminderCancelTap =
      'onboarding_reminder_cancel_tap';

  /// Event logged when user taps donate now during onboarding
  static const String onboardingDonateNowTap = 'onboarding_donate_now_tap';

  /// Event logged when user completes onboarding flow
  static const String onboardingCompleted = 'onboarding_completed';

  /// Event logged when user grants tracking permission during onboarding
  static const String onboardingTrackingPermissionGranted =
      'onboarding_tracking_permission_granted';

  /// Event logged when user denies tracking permission during onboarding
  static const String onboardingTrackingPermissionDenied =
      'onboarding_tracking_permission_denied';

  /// Event logged when user grants notifications permission during onboarding
  static const String onboardingNotificationsPermissionGranted =
      'onboarding_notifications_permission_granted';

  /// Event logged when user denies notifications permission during onboarding
  static const String onboardingNotificationsPermissionDenied =
      'onboarding_notifications_permission_denied';

  // Feedback events
  /// Event logged when user submits post-meditation feedback
  static const String postMeditationFeedback = 'post_meditation_feedback';

  // Audio session events
  /// Event logged when an audio session is completed and stats are updated
  static const String audioSessionCompleted = 'audio_session_completed';

  /// Parameter name for audio file ID
  static const String paramAudioFileId = 'audioFileId';

  /// Parameter name for audio file guide/narrator
  static const String paramAudioFileGuide = 'audioFileGuide';

  /// Parameter name for audio file duration in milliseconds
  static const String paramAudioFileDuration = 'audioFileDuration';

  // Error and token events
  /// Event logged when unexpected logout occurs due to missing refresh token
  static const String unexpectedLogoutRefreshTokenMissing =
      'unexpected_logout_refresh_token_missing';

  /// Event logged when secure storage has persistent failures
  static const String secureStoragePersistentFailure =
      'secure_storage_persistent_failure';

  /// Event logged when token backup storage is attempted
  static const String tokenBackupStorageAttempt =
      'token_backup_storage_attempt';

  /// Event logged with result of token backup storage attempt
  static const String tokenBackupStorageResult = 'token_backup_storage_result';

  /// Event logged when token is retrieved from backup storage
  static const String tokenRetrievedFromBackup = 'token_retrieved_from_backup';

  /// Event logged when token backup is attempted after an error
  static const String tokenBackupAfterErrorAttempt =
      'token_backup_after_error_attempt';

  /// Event logged with result of token backup after error attempt
  static const String tokenBackupAfterErrorResult =
      'token_backup_after_error_result';

  /// Event logged when refresh token retrieval fails
  static const String refreshTokenRetrievalFailed =
      'refresh_token_retrieval_failed';

  /// Event logged when refresh token read error occurs in SharedPreferences
  static const String refreshTokenReadErrorSharedPreferences =
      'refresh_token_read_error_shared_preferences';

  /// Event logged when refresh token read error occurs in SecureStorage
  static const String refreshTokenReadErrorSecureStorage =
      'refresh_token_read_error_secure_storage';

  /// Event logged when email address save fails
  static const String emailAddressSaveFailed = 'email_address_save_failed';

  /// Event logged when email address save fails (second attempt)
  static const String emailAddressSaveFailed2 = 'email_address_save_failed2';

  /// Event logged when auth token storage fails
  static const String authTokenStorageFailed = 'auth_token_storage_failed';

  // Paywall source constants
  /// Paywall source identifier for onboarding flow
  static const String paywallSourceOnboarding = 'onboarding';

  /// Paywall source identifier for settings screen
  static const String paywallSourceSettings = 'settings';

  /// Paywall source identifier for end screen
  static const String paywallSourceEndScreen = 'end_screen';

  /// Paywall source identifier for announcement
  static const String paywallSourceAnnouncement = 'announcement';

  // Analytics parameter names
  /// Parameter name for donation/payment amount
  static const String paramAmount = 'amount';

  /// Parameter name for donation currency
  static const String paramDonationCurrency = 'donation_currency';

  /// Parameter name for paywall identifier
  static const String paramPaywallId = 'paywall_id';

  /// Parameter name for Medito user identifier
  static const String paramMeditoUserId = 'medito_user_id';

  /// Parameter name for paywall source
  static const String paramPaywallSource = 'paywall_source';

  /// Parameter name for payment intent identifier
  static const String paramPaymentIntentId = 'payment_intent_id';

  /// Parameter name for revenue (used by Meta)
  static const String paramRevenue = 'revenue';

  /// Parameter name for currency (used by Meta)
  static const String paramCurrency = 'currency';
}
