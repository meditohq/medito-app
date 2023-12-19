import 'package:flutter_dotenv/flutter_dotenv.dart';

class HTTPConstants {
  static String ENVIRONMENT = dotenv.env['ENVIRONMENT']!;
  static String ENVIRONMENT_DEBUG = dotenv.env['ENVIRONMENT_DEBUG']!;
  static String BASE_URL = dotenv.env['BASE_URL']!;
  static String INIT_TOKEN = dotenv.env['INIT_TOKEN']!;
  static String SENTRY_DSN = dotenv.env['SENTRY_DSN']!;

  //END POINTS
  static const String USERS = 'users';
  static const String OTP = 'otp';
  static const String PACKS = 'packs';
  static const String TRACKS = 'tracks';
  static const String BACKGROUND_SOUNDS = 'backgroundSounds';
  static const String HEADER = 'main/header';
  static const String QUOTE = 'main/quote';
  static const String SHORTCUTS = 'main/shortcuts';
  static const String STATS = 'main/stats';
  static const String ME = 'me';
  static const String EVENTS = 'events';
  static const String SEARCH = 'search';
}
