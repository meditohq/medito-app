import 'package:flutter_dotenv/flutter_dotenv.dart';

class HTTPConstants {
  static String BASE_URL = dotenv.env['BASE_URL']!;
  static String BASE_URL_OLD = dotenv.env['BASE_URL_OLD']!;
  static String INIT_TOKEN = dotenv.env['INIT_TOKEN']!;
  static String CONTENT_TOKEN = dotenv.env['CONTENT_TOKEN']!;
  static String CONTENT_TOKEN_OLD = dotenv.env['CONTENT_TOKEN_OLD']!;
  static String SENTRY_DSN = dotenv.env['SENTRY_DSN']!;

  //END POINTS
  static const String USERS = 'users';
  static const String OTP = 'otp';
  static const String PACKS = 'packs';
  static const String TRACKS = 'tracks';
  static const String BACKGROUND_SOUNDS = 'backgroundSounds';
  static const String HOME = 'home';
  static const String STATS = 'stats';
  static const String ME = 'me';
  static const String EVENTS = 'events';
}
