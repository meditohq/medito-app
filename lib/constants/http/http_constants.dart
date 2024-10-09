import 'package:flutter/foundation.dart';

class EnvConfig {
  final String environment;
  final String contentBaseUrl;
  final String authBaseUrl;
  final String authToken;
  final String sentryDsn;

  const EnvConfig({
    required this.environment,
    required this.contentBaseUrl,
    required this.authBaseUrl,
    required this.authToken,
    required this.sentryDsn,
  });
}

class ProdEnv extends EnvConfig {
  const ProdEnv({
    required super.environment,
    required super.contentBaseUrl,
    required super.authBaseUrl,
    required super.authToken,
    required super.sentryDsn,
  });
}

class StagingEnv extends EnvConfig {
  const StagingEnv({
    required super.environment,
    required super.contentBaseUrl,
    required super.authBaseUrl,
    required super.authToken,
    required super.sentryDsn,
  });
}

const _prodEnv = ProdEnv(
  environment: String.fromEnvironment('ENVIRONMENT'),
  contentBaseUrl: String.fromEnvironment('CONTENT_BASE_URL'),
  authBaseUrl: String.fromEnvironment('AUTH_BASE_URL'),
  authToken: String.fromEnvironment('AUTH_TOKEN'),
  sentryDsn: String.fromEnvironment('SENTRY_DSN'),
);

const _stagingEnv = StagingEnv(
  environment: String.fromEnvironment('ENVIRONMENT'),
  contentBaseUrl: String.fromEnvironment('CONTENT_BASE_URL_V2'),
  authBaseUrl: String.fromEnvironment('AUTH_BASE_URL'),
  authToken: String.fromEnvironment('AUTH_TOKEN'),
  sentryDsn: String.fromEnvironment('SENTRY_DSN'),
);

EnvConfig get _currentEnv => kReleaseMode ? _prodEnv : _stagingEnv;

String get environment => _currentEnv.environment;
String get contentBaseUrl => _currentEnv.contentBaseUrl;
String get authBaseUrl => _currentEnv.authBaseUrl;
String get authToken => _currentEnv.authToken;
String get sentryDsn => _currentEnv.sentryDsn;

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
  static const String like = '/like';
  static const String donate = '/donations/asks?random=true';
}
