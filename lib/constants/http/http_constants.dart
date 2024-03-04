import 'package:flutter_dotenv/flutter_dotenv.dart';

class HTTPConstants {
  static String ENVIRONMENT = dotenv.env['ENVIRONMENT']!;
  static String ENVIRONMENT_DEBUG = dotenv.env['ENVIRONMENT_DEBUG']!;
  static String CONTENT_BASE_URL = dotenv.env['CONTENT_BASE_URL']!;
  static String AUTH_BASE_URL = dotenv.env['AUTH_BASE_URL']!;
  static String AUTH_TOKEN = dotenv.env['AUTH_TOKEN']!;
  static String SENTRY_DSN = dotenv.env['SENTRY_DSN']!;

  //END POINTS
  static const String TOKENS = 'tokens';
  static const String USERS = 'users';
  static const String OTP = 'otp';
  static const String PACKS = 'packs';
  static const String TRACKS = 'tracks';
  static const String BACKGROUND_SOUNDS = 'backgroundSounds';
  static const String HOME = 'home';
  static const String LATEST_ANNOUNCEMENT = 'announcements?latest=true';
  static const String HEADER = 'main/header';
  static const String QUOTE = 'main/quote';
  static const String SHORTCUTS = 'main/shortcuts';
  static const String EDITORIAL = 'main/editorial';
  static const String STATS = '/stats';
  static const String ME = 'me';
  static const String EVENTS = 'events';
  static const String SEARCH = 'search';

  // MAINTENANCE END POINTS
  static const String MAINTENANCE = 'https://api.medito.app/v1/maintenance';

  // EVENT END POINTS
  static const String AUDIO = '/audio';
  static const String AUDIO_START_EVENT = '/start';
  static const String ANNOUNCEMENT_EVENT = '/announcements';
  static const String ANNOUNCEMENT_DISMISS_EVENT = '/dismiss/';
  static const String COMPLETE_EVENT = '/complete';
  static const String FIREBASE_EVENT = '/fcm';
}
