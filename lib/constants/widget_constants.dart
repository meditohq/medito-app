class WidgetConstants {
  static const String taskIdentifier =
      'meditationStatsWidgetUpdate'; // Used for periodic widget update
  static const String taskName =
      'updateMeditationStatsWidget'; // Used for periodic widget update
  static const String widgetGroupId = 'group.org.medito.widget';

  // Widget kinds for iOS
  static const String quoteWidgetSmallKind = 'QuoteWidgetSmall';
  static const String streakWidgetSmallKind = 'StreakWidgetSmall';
  static const String streakWidgetMediumKind = 'StreakWidgetMedium';

  // Widget data keys
  static const String currentStreakKey = 'current_streak';
  static const String bestStreakKey = 'best_streak';
  static const String totalTimeKey = 'total_time';
  static const String totalSessionsKey = 'total_sessions';
  static const String quoteTextKey = 'quote_text';
  static const String quoteAuthorKey = 'quote_author';
  static const String lastUpdatedKey = 'last_updated_time';
}
