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
  contentBaseUrl: String.fromEnvironment('CONTENT_BASE_URL'),
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
  static const String TOKENS = 'tokens';
  static const String PACKS = 'packs';
  static const String TRACKS = 'tracks';
  static const String BACKGROUND_SOUNDS = 'backgroundsounds';
  static const String HOME = 'home';
  static const String LATEST_ANNOUNCEMENT = 'announcements?latest=true';
  static const String STATS = '/stats';
  static const String ME = 'me';
  static const String SEARCH_TRACKS = 'search/tracks';

  // MAINTENANCE END POINTS
  static const String MAINTENANCE = 'https://api.medito.app/v1/maintenance';

  // EVENT END POINTS
  static const String AUDIO = '/audio';
  static const String AUDIO_START_EVENT = '/start';
  static const String ANNOUNCEMENT_EVENT = '/announcements';
  static const String ANNOUNCEMENT_DISMISS_EVENT = '/dismiss';
  static const String COMPLETE_EVENT = '/complete';
  static const String FIREBASE_EVENT = '/fcm';
  static const String RATE = '/rate';
  static const String LIKE = '/like';
  static const String DONATE = '/donations/asks?random=true';
}
