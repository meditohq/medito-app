import 'package:flutter_dotenv/flutter_dotenv.dart';

class HTTPConstants {
  static String BASE_URL = dotenv.env['BASE_URL']!;
  static String BASE_URL_OLD = dotenv.env['BASE_URL_OLD']!;
  static String INIT_TOKEN = dotenv.env['INIT_TOKEN']!;
  static String CONTENT_TOKEN = dotenv.env['CONTENT_TOKEN']!;
  static String CONTENT_TOKEN_OLD = dotenv.env['CONTENT_TOKEN_OLD']!;
  static String SENTRY_URL = dotenv.env['SENTRY_URL']!;
  static const String FOLDERS = 'folders';
  static const String SESSIONS = 'sessions';
  static const String BACKGROUND_SOUNDS = 'backgroundSounds';
}
