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

  /// Event logged when the paywall is presented to the user
  static const String paywallPresented = 'paywall_presented';

  /// Event logged when paywall is dismissed without completing a payment
  static const String paywallDismissedNoPayment =
      'paywall_dismissed_no_payment';

  /// Fired just before the wallet/card sheet opens. The checkout denominator:
  /// sheets = success + failed + cancelled + silent abandonment.
  static const String paymentSheetPresented = 'payment_sheet_presented';

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

  /// Event logged when the onboarding donation step first becomes visible —
  /// the true top of the onboarding donation funnel.
  ///
  /// Without it the earliest measurable event was [onboardingDonateNowTap]
  /// (webview arm) or the paywall itself, so the ask's own impression count had
  /// to be proxied by [onboardingQuestionFlowCompleted]. Parameter
  /// [paramWouldBeVariant] records which arm rendered ('native' / 'webview'),
  /// since the two have different downstream funnels — the native page has no
  /// intro-tap step at all.
  static const String onboardingDonationScreenShown =
      'onboarding_donation_screen_shown';

  /// Event logged when user taps donate now during onboarding
  static const String onboardingDonateNowTap = 'onboarding_donate_now_tap';

  /// Event logged when user skips donation during onboarding
  static const String onboardingDonationSkipTap =
      'onboarding_donation_skip_tap';

  /// Event logged when user completes onboarding flow
  static const String onboardingCompleted = 'onboarding_completed';

  // Onboarding "first meditation" experiment (onboarding_first_meditation).
  /// Fired once per install when onboarding assigns the user to an experiment
  /// arm. Carries paramExperimentName + paramVariantId so the test is queryable
  /// with the same BigQuery convention as the paywall experiments.
  static const String onboardingExperimentExposure =
      'onboarding_experiment_exposure';

  /// The first-meditation screen (variant arm) was shown.
  static const String onboardingFirstMeditationShown =
      'onboarding_first_meditation_shown';

  /// User tapped "Begin" to start the first meditation from onboarding.
  static const String onboardingFirstMeditationBeginTap =
      'onboarding_first_meditation_begin_tap';

  /// User skipped the first meditation ("Maybe later").
  static const String onboardingFirstMeditationSkipTap =
      'onboarding_first_meditation_skip_tap';

  /// Parameter on onboardingReminderSetTap (chips arm of the
  /// onboarding_reminder_time_chips experiment): which time slot the user
  /// picked — 'morning', 'evening', 'night', or 'custom'.
  static const String paramReminderSlot = 'reminder_slot';

  /// Event logged when the pre-permission soft-ask is shown on the onboarding
  /// reminder screen, and when the user declines it. This is where the
  /// irreversible damage happens: every iOS denial recorded at this step is
  /// permanently_denied, so the system prompt never returns and no later
  /// surface can recover the user. A decline here leaves them askable.
  /// Continues to the system prompt = shown - declined.
  static const String onboardingReminderPrimerShown =
      'onboarding_reminder_primer_shown';
  static const String onboardingReminderPrimerDeclined =
      'onboarding_reminder_primer_declined';

  /// Event logged when the user taps the "Pick my own time" chip, BEFORE the
  /// time picker opens. Only a successful pick used to fire an event, so
  /// opening the picker and backing out left no trace; pairs with
  /// [onboardingReminderCustomCancel] to measure that drop-off.
  static const String onboardingReminderCustomTap =
      'onboarding_reminder_custom_tap';

  /// Event logged when the user dismisses the custom time picker without
  /// choosing a time. See [onboardingReminderCustomTap].
  static const String onboardingReminderCustomCancel =
      'onboarding_reminder_custom_cancel';

  /// Parameters on onboardingReminderSetTap carrying the hour (0-23) and
  /// minute the reminder series was actually anchored to, for both arms — so
  /// the control arm's implicit "same time tomorrow" default is comparable
  /// with a deliberate pick. [paramReminderSlot] only names the chip, which
  /// says nothing about what time the Custom pickers chose. Two ints rather
  /// than a formatted string keeps GA4 cardinality low.
  static const String paramReminderHour = 'reminder_hour';
  static const String paramReminderMinute = 'reminder_minute';

  /// Event logged on the user's very first interactive tap after completing
  /// onboarding. Fires exactly once per install.
  /// Parameter: paramTarget — describes what they tapped (e.g. 'up_next',
  /// 'shortcut', 'carousel', 'tab_explore', 'tab_settings', 'stats', 'product')
  static const String firstActionAfterOnboarding =
      'first_action_after_onboarding';

  /// Parameter for what the user tapped in firstActionAfterOnboarding
  static const String paramTarget = 'target';

  /// Event logged when user grants tracking permission during onboarding
  static const String onboardingTrackingPermissionGranted =
      'onboarding_tracking_permission_granted';

  /// Event logged when user denies tracking permission during onboarding
  static const String onboardingTrackingPermissionDenied =
      'onboarding_tracking_permission_denied';

  /// Event logged when user grants notifications permission during onboarding.
  /// Name is abbreviated ("notif" not "notifications") to stay within Firebase
  /// Analytics' 40-character event-name limit — the longer form was silently
  /// dropped and produced zero events in BigQuery.
  static const String onboardingNotificationsPermissionGranted =
      'onboarding_notif_permission_granted';

  /// Event logged when user denies notifications permission during onboarding.
  /// See note on [onboardingNotificationsPermissionGranted].
  static const String onboardingNotificationsPermissionDenied =
      'onboarding_notif_permission_denied';

  /// Impression event for the onboarding notifications screen copy A/B test.
  /// Logged once per screen render with a `variant` parameter ('a' or 'b').
  static const String onboardingNotificationsPreviewShown =
      'onboarding_notifications_preview_shown';

  // Feedback events
  /// Event logged when user submits post-meditation feedback
  static const String postMeditationFeedback = 'post_meditation_feedback';

  // Audio session events
  /// Event logged when an audio session is completed and stats are updated
  static const String audioSessionCompleted = 'audio_session_completed';

  /// Event logged once when playback of a track actually begins. Provides the
  /// denominator for completion rate. Same params as [audioSessionCompleted].
  static const String audioSessionStarted = 'audio_session_started';

  /// Event logged once when a started session ends WITHOUT completing
  /// (close, switch track, navigate-away-while-paused, background-while-paused,
  /// or replayed on next launch after a force-quit). Carries
  /// [paramPercentCompleted] and [paramElapsedSeconds] for drop-off analysis.
  /// See docs/ANALYTICS_SESSION_EVENTS.md for exact fire conditions.
  static const String audioSessionAbandoned = 'audio_session_abandoned';

  /// Parameter name for audio file ID
  static const String paramAudioFileId = 'audioFileId';

  /// Parameter name for audio file guide/narrator
  static const String paramAudioFileGuide = 'audioFileGuide';

  /// Parameter name for audio file duration in milliseconds
  static const String paramAudioFileDuration = 'audioFileDuration';

  /// Parameter for how far into the track the user got when abandoning,
  /// as an integer percent rounded to the nearest 10 and clamped to 0..90.
  static const String paramPercentCompleted = 'percent_completed';

  /// Parameter for elapsed playback time in whole seconds when abandoning.
  static const String paramElapsedSeconds = 'elapsed_seconds';

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

  /// Event logged when refresh token read error occurs in SharedPreferences.
  /// Name is abbreviated to stay within Firebase Analytics' 40-character limit.
  static const String refreshTokenReadErrorSharedPreferences =
      'refresh_token_read_err_shared_prefs';

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

  /// Our own slug for a failure. Expect a lot of 'generic_error' — the
  /// Stripe-native params below are what actually identify a cause.
  static const String paramFailureReason = 'failure_reason';

  /// Stripe FailureCode: "Failed" | "Canceled" | "Timeout" | "Unknown".
  static const String paramStripeCode = 'stripe_code';

  /// Stripe's API-level error code.
  static const String paramStripeErrorCode = 'stripe_error_code';

  /// Stripe's decline_code, e.g. "insufficient_funds".
  static const String paramDeclineCode = 'decline_code';

  /// Stripe's error type, e.g. "card_error".
  static const String paramStripeErrorType = 'stripe_error_type';

  /// 'apple_pay' | 'google_pay' | 'card'. Only iOS with a wallet gets the
  /// one-tap confirm; everything else falls through to the full PaymentSheet.
  static const String paramPaymentMethod = 'payment_method';

  /// 'one_time' | 'monthly' | 'yearly'.
  static const String paramPaymentFrequency = 'payment_frequency';

  /// Parameter name for donation page A/B test variant
  static const String paramVariantId = 'variant_id';

  /// Parameter name for an experiment's human-readable name/slug (e.g.
  /// "onboarding_first_meditation"). Matches the BigQuery convention used to
  /// segment experiments alongside [paramVariantId].
  static const String paramExperimentName = 'experiment_name';

  /// Parameter name for the active experiment slug/ID (e.g. "donate3"). This
  /// is the stable identifier and matches what's attached to Stripe payment
  /// metadata under the same key. Source: JS bridge `experiment_id` field.
  static const String paramExperimentId = 'experiment_id';

  /// Event logged once when the donation/paywall page is viewed in the in-app webview
  static const String donationPageViewed = 'donation_page_viewed';

  /// Event logged when the in-app paywall webview begins loading. Paired with
  /// [paywallWebviewLoadFinished] / [paywallWebviewLoadFailed] so the funnel
  /// between paywall_presented and donation_page_viewed can be split into
  /// "loaded successfully but bounced" vs "never loaded".
  static const String paywallWebviewLoadStarted =
      'paywall_webview_load_started';

  /// Event logged when the in-app paywall webview finishes loading. Includes
  /// a `duration_ms` parameter measured from load start.
  static const String paywallWebviewLoadFinished =
      'paywall_webview_load_finished';

  /// Event logged when the in-app paywall webview fails to load (main-frame
  /// error or load timeout). Includes `duration_ms` and `reason`.
  static const String paywallWebviewLoadFailed = 'paywall_webview_load_failed';

  /// Event logged when the paywall config does not arrive before the onboarding
  /// donation screen's wait expires, so the user is served the webview arm
  /// regardless of the arm the server would have assigned. Without this event
  /// those users are indistinguishable from genuine variant-A traffic, and
  /// because the trigger is a slow config fetch they skew slow-network — which
  /// biases conversion, not just arm volume. Includes `duration_ms` (the wait
  /// that elapsed) and `paywall_source`.
  static const String paywallConfigTimeout = 'paywall_config_timeout';

  /// Event logged when the paywall config arrives *after* the screen already
  /// fell back to the webview arm. Carries `would_be_variant` — the arm the
  /// config actually specified — which is what makes the native_paywall
  /// denominator correctable: it reports how many fallback users the server
  /// had assigned to the native arm. Also includes `paywall_source`.
  static const String paywallConfigLateArrival = 'paywall_config_late_arrival';

  /// Parameter carrying the arm a late-arriving paywall config specified, for
  /// users already committed to the webview fallback ('native' or 'webview').
  static const String paramWouldBeVariant = 'would_be_variant';

  /// Parameter for elapsed load time in milliseconds (paywall webview events)
  static const String paramDurationMs = 'duration_ms';

  /// Parameter for the reason a paywall webview load failed
  /// ('timeout' or 'main_frame_error').
  static const String paramReason = 'reason';

  /// Parameter name for revenue (used by Meta)
  static const String paramRevenue = 'revenue';

  /// Parameter name for currency (used by Meta)
  static const String paramCurrency = 'currency';

  // Up Next widget events
  /// Event logged when user taps the Up Next widget to start a session
  static const String upNextTapped = 'up_next_tapped';

  /// Event logged when user swipes to skip the Up Next session
  static const String upNextSkipped = 'up_next_skipped';

  /// The pinned pack is finished and the completed state was shown.
  static const String upNextPackCompleted = 'up_next_pack_completed';

  /// The completed-state CTA was accepted and the next pack pinned.
  static const String upNextNextPackPinned = 'up_next_next_pack_pinned';

  /// The user finished the last pack on the path (or the megapack).
  static const String upNextPathCompleted = 'up_next_path_completed';

  /// Parameter name for the session/track ID in up next events
  static const String paramSessionId = 'session_id';

  /// Parameter name for the pack ID in up next events
  static const String paramPackId = 'pack_id';

  /// The pack pinned by the completed-state CTA.
  static const String paramNextPackId = 'next_pack_id';

  /// Path position being moved into.
  static const String paramNextPackSequencePosition =
      'next_pack_sequence_position';

  /// 1-based position on the path, or 'none' when off it.
  static const String paramPackSequencePosition = 'pack_sequence_position';

  /// Whether the completed state had a next pack to offer.
  static const String paramHasNextPack = 'has_next_pack';

  /// 'megapack' | 'sequence' | 'custom' — which Up Next cohort the user is in.
  static const String paramUpNextMode = 'up_next_mode';

  /// 1-based index of the session within its pack.
  static const String paramSessionIndexInPack = 'session_index_in_pack';

  static const String paramPackTotalSessions = 'pack_total_sessions';

  // Pin events
  /// Event logged when user pins a pack as Up Next from the pack screen
  static const String packPinned = 'pack_pinned';

  /// Event logged when user unpins a pack from Up Next on the pack screen
  static const String packUnpinned = 'pack_unpinned';

  // Home-screen widget events (iOS + Android)
  /// Event logged when the user taps a home-screen widget. Detected via the
  /// `source=home_widget` query param on the deep link the widget fires.
  static const String homeWidgetTapped = 'home_widget_tapped';

  /// Event logged when the user successfully pins a widget from in-app
  /// (Android only — iOS doesn't expose a programmatic pin API).
  static const String homeWidgetPinRequested = 'home_widget_pin_requested';

  /// Parameter naming the widget kind: `up_next`, `streak`, `consistency`.
  static const String paramWidgetType = 'widget_type';

  /// Sentinel value for the `source` deep-link query param that identifies
  /// the link as coming from a home-screen widget tap.
  static const String widgetDeepLinkSource = 'home_widget';

  // Your Path explainer strip events
  /// Event logged when the Your Path explainer strip is shown to the user
  static const String yourPathExplainerShown = 'your_path_explainer_shown';

  /// Event logged when the Your Path explainer strip is dismissed
  /// Parameter: dismissMethod — 'got_it' (tapped button) or 'auto' (timed out)
  static const String yourPathExplainerDismissed =
      'your_path_explainer_dismissed';

  /// Parameter for how the explainer was dismissed ('got_it' or 'auto')
  static const String paramDismissMethod = 'dismiss_method';

  // Onboarding question/result events
  /// Event logged when the new onboarding question flow is started
  static const String onboardingQuestionFlowStarted =
      'onboarding_question_flow_started';

  /// Event logged when the user answers the experience level question
  /// Parameter: paramAnswer ('never_tried', 'a_little', 'regular_practice')
  static const String onboardingExperienceAnswered =
      'onboarding_experience_answered';

  /// Event logged when the user answers the intent question
  /// Parameter: paramAnswer ('learn_properly', 'build_habit', 'stress_sleep_emotions')
  static const String onboardingIntentAnswered = 'onboarding_intent_answered';

  /// Parameter for the selected answer in onboarding question events
  static const String paramAnswer = 'answer';

  /// GA4 user property holding the onboarding experience answer
  /// ('never_tried', 'a_little', 'regular_practice'). Set once when the user
  /// answers, so all downstream events — including the first-meditation A/B
  /// test — can be segmented by experience level in BigQuery.
  static const String userPropExperienceLevel = 'experience_level';

  /// Parameter carrying the free-text response from the onboarding attribution
  /// question when the user picks the "other" path and types their own answer.
  static const String paramOtherText = 'other_text';

  /// Event logged when the new onboarding question flow is completed
  /// Parameter: paramResultState — 'state_a', 'state_b', or 'state_c'
  static const String onboardingQuestionFlowCompleted =
      'onboarding_question_flow_completed';

  /// Parameter for the result state shown on the onboarding result screen
  static const String paramResultState = 'result_state';

  /// Event logged when the user abandons the new onboarding question flow before completion
  static const String onboardingQuestionFlowAbandoned =
      'onboarding_question_flow_abandoned';

  /// Event logged when the user answers the attribution question ("how did you hear about us?")
  /// Parameter: paramAnswer ('google_ad', 'social_ad', 'friend', 'therapist', 'app_store', 'play_store', 'other')
  static const String onboardingAttributionAnswered =
      'onboarding_attribution_answered';

  /// Event logged when the end-screen donation card first becomes visible in
  /// its ASK state (the amount/CTA card, not the post-donation thank-you).
  ///
  /// This is the denominator the end-screen donation funnel never had: the card
  /// renders on every end screen unless snoozed, but [donationPageViewed] only
  /// fires once the user taps through and the webview loads, so tap-through was
  /// previously unmeasurable and had to be proxied by `audio_session_completed`
  /// (which over-counts — one user sees the card many times).
  /// Parameter: [paramPaywallSource] (always 'end_screen').
  static const String endScreenDonationCardShown =
      'end_screen_donation_card_shown';

  /// Event logged when the end-screen donation card renders in its snoozed
  /// thank-you state instead of the ask. Keeps [endScreenDonationCardShown] a clean
  /// ask-impression count while still accounting for every render, so
  /// suppression volume is visible rather than silently missing.
  static const String endScreenDonationCardSuppressed =
      'end_screen_donation_card_suppressed';

  /// Event logged when the end-screen donation card fails to load its CMS
  /// content (an impression that could never convert). Analogous to
  /// [paywallWebviewLoadFailed] one step earlier in the funnel.
  static const String endScreenDonationCardLoadFailed =
      'end_screen_donation_card_load_failed';

  /// Event logged when the user taps a donate CTA on the end-screen donation
  /// card, BEFORE any navigation or webview load. Pairs with
  /// [donationPageViewed] to split "tapped but the paywall never rendered"
  /// from "saw the paywall and bounced".
  /// Parameters: [paramPaywallSource], [paramButtonIndex], [paramCardState].
  static const String endScreenDonationCardDonateTap =
      'end_screen_donation_card_donate_tap';

  /// Event logged when the user snoozes the donation ask for 30 days from the
  /// card's info dialog ("Hide for now").
  static const String endScreenDonationCardSnoozed =
      'end_screen_donation_card_snoozed';

  /// Event logged when the user opens the "?" info dialog on the donation card.
  static const String endScreenDonationCardInfoOpened =
      'end_screen_donation_card_info_opened';

  /// Parameter naming which donate CTA was tapped when the CMS supplies more
  /// than one button (0-based).
  static const String paramButtonIndex = 'button_index';

  /// Parameter distinguishing the donation card's render state: 'ask' (first
  /// or repeat ask) vs 'thanks' (post-donation "Donate again").
  static const String paramCardState = 'card_state';

  /// Event logged when the end-screen smart-reminders card first becomes
  /// visible to the user (i.e. shouldShowReminderPromptProvider is true).
  static const String endScreenReminderPromptShown =
      'end_screen_reminder_prompt_shown';

  /// Event logged when the user taps "Not now" on the end-screen reminders card
  /// (7-day snooze).
  static const String endScreenReminderPromptSnoozed =
      'end_screen_reminder_prompt_snoozed';

  /// Event logged when the user taps the ✕ button on the end-screen reminders
  /// card (permanent dismiss).
  static const String endScreenReminderPromptDismissed =
      'end_screen_reminder_prompt_dismissed';

  /// Event logged when the user taps "Turn on smart reminders" but the OS
  /// permission dialog returns denied.
  static const String endScreenReminderOsDenied =
      'end_screen_reminder_os_denied';

  /// Event logged when the pre-permission soft-ask is shown, and when the user
  /// declines it. A decline never raises the system dialog, so these users
  /// remain askable on a later session — unlike a system-level denial, which
  /// is permanent on iOS. Continues to the system prompt = shown - declined.
  static const String endScreenReminderPrimerShown =
      'end_screen_reminder_primer_shown';
  static const String endScreenReminderPrimerDeclined =
      'end_screen_reminder_primer_declined';

  /// The "permission is permanently denied, go to the phone's settings" flow,
  /// shared by onboarding, the end-screen card and the settings tile — the
  /// [paramSource] param says which. Sending someone to settings used to be a
  /// one-way trip with no follow-up, so none of it was measurable:
  /// [notificationSettingsPromptShown] is the ask, [notificationSettingsOpened]
  /// is them going, and [notificationPermissionRecovered] is the payoff — a
  /// user who came back with permission granted and had their reminder set up
  /// for them rather than having to tap the control a second time.
  static const String notificationSettingsPromptShown =
      'notification_settings_prompt_shown';
  static const String notificationSettingsOpened =
      'notification_settings_opened';
  static const String notificationPermissionRecovered =
      'notification_permission_recovered';

  /// Event logged when permission was granted but scheduling the reminder
  /// series then threw. Without it this failure was silent in both the UI and
  /// analytics: the user appears to have enabled reminders and never gets one.
  static const String endScreenReminderEnableFailed =
      'end_screen_reminder_enable_failed';

  /// Event logged when the user enables smart reminders/notifications.
  /// Parameter: paramSource ('end_screen', 'settings')
  static const String notificationsEnabled = 'notifications_enabled';

  /// Event logged when the user disables smart reminders/notifications.
  /// Parameter: paramSource ('settings')
  static const String notificationsDisabled = 'notifications_disabled';

  /// Parameter name for the source screen that triggered a notifications_enabled
  /// or notifications_disabled event
  static const String paramSource = 'source';

  /// Source value for notifications enabled from the end screen
  static const String sourceEndScreen = 'end_screen';

  /// Source value for notifications enabled from the settings screen
  static const String sourceSettings = 'settings';

  // Shortcut events
  /// Event logged when the user taps a shortcut chip on the home screen.
  /// Parameters: paramShortcutId, paramShortcutTitle, paramShortcutType
  static const String shortcutTapped = 'shortcut_tapped';

  /// Parameter name for the shortcut id in shortcut_tapped events
  static const String paramShortcutId = 'shortcut_id';

  /// Parameter name for the shortcut human-readable title
  static const String paramShortcutTitle = 'shortcut_title';

  /// Parameter name for the shortcut destination type (e.g. pack, track, link)
  static const String paramShortcutType = 'shortcut_type';

  // Favourite events
  /// Event logged when user adds a track to favourites from the track screen
  static const String trackFavourited = 'track_favourited';

  /// Event logged when user removes a track from favourites on the track screen
  static const String trackUnfavourited = 'track_unfavourited';

  /// Event logged when user adds a pack to favourites from the pack screen
  static const String packFavourited = 'pack_favourited';

  /// Event logged when user removes a pack from favourites on the pack screen
  static const String packUnfavourited = 'pack_unfavourited';

  // Quote share events
  /// Event logged when the user opens the quote share screen by tapping the
  /// daily quote widget on the home screen.
  /// Parameters: paramQuoteId, paramQuoteAuthor
  static const String quoteShareOpened = 'quote_share_opened';

  /// Event logged when the user actually triggers the OS share sheet from the
  /// quote share screen.
  /// Parameters: paramQuoteId, paramQuoteAuthor, paramQuoteSharePalette
  static const String quoteShared = 'quote_shared';

  /// Parameter name for the daily quote's id.
  static const String paramQuoteId = 'quote_id';

  /// Parameter name for the daily quote's author.
  static const String paramQuoteAuthor = 'quote_author';

  /// Parameter name for the background palette selected on the quote share
  /// screen (e.g. 'Midnight', 'Cream'). Lets us see which backgrounds people
  /// actually pick.
  static const String paramQuoteSharePalette = 'palette';
}
