class SharedPreferenceConstants {
  static const String user = 'user';
  static const String bgSoundVolume = 'bgSoundVolume';
  static const String bgSound = 'bgSound';
  static const String listBgSound = 'listBgSound';
  static const String downloads = 'downloads';
  static const String currentPlayingTrack = 'currentPlayingTrack';
  static const String shortcuts = 'shortcuts';
  static const String savedHours = 'savedHours';
  static const String savedMinutes = 'savedMinutes';
  static const String lastSelectedGuideName = 'lastSelectedGuideName';
  static const String favoritePacks = 'favorite_packs';
  static const String favorites = 'favorites';

  static const String userId = 'userId';
  static const String userEmail = 'userEmail';
  static const String userToken = 'userToken';

  // New constants for stats
  static const String localAllStatsKey = 'local_all_stats';
  static const String statsLastSyncedAt = 'stats_last_synced_at';
  static const String hasSeenStreakCircle = 'has_seen_streak_circle';
  static const String streakCircleDisplayPreference =
      'streak_circle_display_preference';

  static const String homeWidgetOrder = 'homeWidgetOrder';

  // DND settings
  static const String dndEnabled = 'dnd_enabled';
  static const String isLoggedIn = 'is_logged_in';

  static const String hasActiveSubscription = 'has_active_subscription';

  // Locale preference - stores the user's preferred language setting
  static const String localePreference = 'locale_preference';

  // Theme preference - stores the user's preferred theme mode
  static const String themePreference = 'theme_preference';

  // Smart Reminders
  static const String dailyReminderEnabled = 'daily_reminder_enabled';
  static const String reminderPromptDismissedForever = 'reminder_prompt_dismissed_forever';

  // Zen Mode
  static const String zenModeEnabled = 'zen_mode_enabled';

  // Analytics consent flags
  static const String analyticsFirebaseEnabled = 'analytics_firebase_enabled';
  static const String analyticsMetaEnabled = 'analytics_meta_enabled';

  // Historical consistency score data
  static const String consistencyScoreHistory = 'consistency_score_history';

  // Black Friday positioning
  static const String blackFridayDismissed = 'black_friday_dismissed';

  // UTM parameters (stored from deep links, applied after user initialization)
  static const String utmSource = 'utm_source';
  static const String utmMedium = 'utm_medium';
  static const String utmCampaign = 'utm_campaign';
  static const String utmTerm = 'utm_term';
  static const String utmContent = 'utm_content';

  // Donation snooze tracking
  static const String donationAskSnoozedUntilMs = 'donation_ask_snoozed_until_ms';
  static const String lastSuccessfulDonationAtMs = 'last_successful_donation_at_ms';
  static const String lastSuccessfulDonationFrequency = 'last_successful_donation_frequency';

  // Up Next pack preference
  static const String upNextPackId = 'up_next_pack_id';

  // Your Path explainer strip — set to true once the strip has been dismissed
  static const String hasSeenYourPathExplainer = 'has_seen_your_path_explainer';

  // Last selected main tab (home=0, explore=1)
  static const String lastMainTabIndex = 'last_main_tab_index';

  // History of installed app versions seen on this device (JSON list)
  static const String installedVersionHistory = 'installed_version_history';

  // History of sign-in events on this device (JSON list)
  static const String signedInUserHistory = 'signed_in_user_history';
}
