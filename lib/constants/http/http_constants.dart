import 'package:flutter_dotenv/flutter_dotenv.dart';

class HTTPConstants {
  static String BASE_URL = dotenv.env['BASE_URL']!;
  static String BASE_URL_OLD = dotenv.env['BASE_URL_OLD']!;
  static String INIT_TOKEN = dotenv.env['INIT_TOKEN']!;
  static String CONTENT_TOKEN = dotenv.env['CONTENT_TOKEN']!;
  static String CONTENT_TOKEN_OLD = dotenv.env['CONTENT_TOKEN_OLD']!;
  static String SENTRY_URL = dotenv.env['SENTRY_URL']!;

  //END POINTS
  static const String USERS = 'users';
  static const String OTP = 'otp';
  static const String FOLDERS = 'folders';
  static const String MEDITATIONS = 'meditations';
  static const String BACKGROUND_SOUNDS = 'backgroundSounds';
  static const String HOME = 'home';
  static const String STATS = 'stats';
}
