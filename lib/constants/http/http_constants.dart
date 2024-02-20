import 'package:flutter_dotenv/flutter_dotenv.dart';

class HTTPConstants {
  static String ENVIRONMENT = dotenv.env['ENVIRONMENT']!;
  static String ENVIRONMENT_DEBUG = dotenv.env['ENVIRONMENT_DEBUG']!;
  static String CONTENT_BASE_URL = dotenv.env['CONTENT_BASE_URL']!;
  static String INIT_TOKEN = dotenv.env['INIT_TOKEN']!;
  static String SENTRY_DSN = dotenv.env['SENTRY_DSN']!;

  //END POINTS
  static const String TOKENS = 'tokens';
  static const String USERS = 'users';
  static const String OTP = 'otp';
  static const String PACKS = 'packs';
  static const String TRACKS = 'tracks';
  static const String BACKGROUND_SOUNDS = 'backgroundSounds';
  static const String HOME = 'home';
  static const String LATEST_ANNOUNCEMENT = 'announcements/latest';
  static const String HEADER = 'main/header';
  static const String QUOTE = 'main/quote';
  static const String SHORTCUTS = 'main/shortcuts';
  static const String EDITORIAL = 'main/editorial';
  static const String STATS = 'main/stats';
  static const String ME = 'me';
  static const String EVENTS = 'events';
  static const String SEARCH = 'search';

  // MAINTENANCE END POINTS
  static const String MAINTENANCE = 'https://api.medito.app/v1/maintenance';

  // EVENT END POINTS
  static const String ANNOUNCEMENT_EVENT = 'announcements/dismiss/';
  static const String MARK_AS_LISTENED_EVENT = 'complete/';
}
