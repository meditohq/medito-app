import 'package:flutter/foundation.dart';

class EnvConfig {
  final String environment;
  final String contentBaseUrl;
  final String authBaseUrl;
  final String authToken;
  final String supabaseKey;
  final String supabaseUrl;
  final String editStatsUrl;
  final String revenueCatIOSKey;
  final String revenueCatAndroidKey;

  const EnvConfig({
    required this.environment,
    required this.contentBaseUrl,
    required this.authBaseUrl,
    required this.authToken,
    required this.supabaseKey,
    required this.supabaseUrl,
    required this.editStatsUrl,
    required this.revenueCatIOSKey,
    required this.revenueCatAndroidKey,
  });
}

class ProdEnv extends EnvConfig {
  const ProdEnv({
    required super.environment,
    required super.contentBaseUrl,
    required super.authBaseUrl,
    required super.authToken,
    required super.supabaseKey,
    required super.supabaseUrl,
    required super.editStatsUrl,
    required super.revenueCatIOSKey,
    required super.revenueCatAndroidKey,
  });
}

class StagingEnv extends EnvConfig {
  const StagingEnv({
    required super.environment,
    required super.contentBaseUrl,
    required super.authBaseUrl,
    required super.authToken,
    required super.supabaseKey,
    required super.supabaseUrl,
    required super.editStatsUrl,
    required super.revenueCatIOSKey,
    required super.revenueCatAndroidKey,
  });
}

const _prodEnv = ProdEnv(
  supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
  supabaseKey: String.fromEnvironment('SUPABASE_KEY'),
  environment: String.fromEnvironment('ENVIRONMENT'),
  contentBaseUrl: String.fromEnvironment('CONTENT_BASE_URL'),
  authBaseUrl: String.fromEnvironment('AUTH_BASE_URL'),
  authToken: String.fromEnvironment('AUTH_TOKEN'),
  editStatsUrl: String.fromEnvironment('EDIT_STATS_URL'),
  revenueCatIOSKey: String.fromEnvironment('REVENUECAT_IOS_KEY'),
  revenueCatAndroidKey: String.fromEnvironment('REVENUECAT_ANDROID_KEY'),
);

const _stagingEnv = StagingEnv(
  supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
  supabaseKey: String.fromEnvironment('SUPABASE_KEY'),
  environment: String.fromEnvironment('ENVIRONMENT'),
  contentBaseUrl: String.fromEnvironment('CONTENT_BASE_URL'),
  authBaseUrl: String.fromEnvironment('AUTH_BASE_URL'),
  authToken: String.fromEnvironment('AUTH_TOKEN'),
  editStatsUrl: String.fromEnvironment('EDIT_STATS_URL'),
  revenueCatIOSKey: String.fromEnvironment('REVENUECAT_IOS_KEY'),
  revenueCatAndroidKey: String.fromEnvironment('REVENUECAT_ANDROID_KEY'),
);

EnvConfig get _currentEnv => kReleaseMode ? _prodEnv : _stagingEnv;

String get supabaseUrl => _currentEnv.supabaseUrl;
String get supabaseKey => _currentEnv.supabaseKey;
String get environment => _currentEnv.environment;
String get contentBaseUrl => _currentEnv.contentBaseUrl;
String get authBaseUrl => _currentEnv.authBaseUrl;
String get authToken => _currentEnv.authToken;
String get editStatsUrl => _currentEnv.editStatsUrl;
String get revenueCatIOSKey => _currentEnv.revenueCatIOSKey;
String get revenueCatAndroidKey => _currentEnv.revenueCatAndroidKey;

class HTTPConstants {
  //END POINTS
  static const String tokens = 'tokens';
  static const String packs = 'packs';
  static const String tracks = 'tracks';
  static const String backgroundSounds = 'backgroundsounds';
  static const String home = 'home';
  static const String latestAnnouncement = 'announcements?latest=true';
  static const String allStats = '/stats';
  static const String me = 'me';
  static const String searchTracks = 'search/tracks';

  // MAINTENANCE END POINTS
  static String maintenance = '${contentBaseUrl}maintenance';

  // EVENT END POINTS
  static const String audio = '/audio';
  static const String announcementEvent = '/announcements';
  static const String announcementDismissEvent = '/dismiss';
  static const String completeEvent = '/complete';
  static const String firebaseEvent = '/fcm';
  static const String rate = '/rate';
  static const String favorite = '/favorite';
  static const String donate = '/donations/asks?random=true';
}
