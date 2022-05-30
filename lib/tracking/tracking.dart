/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/
import 'package:Medito/network/folder/folder_response.dart';
import 'package:Medito/network/user/user_utils.dart';
import 'package:Medito/network/auth.dart';
import 'package:Medito/network/http_get.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info/package_info.dart';
import 'package:pedantic/pedantic.dart';

class Tracking {
  static const String FOLDER_TAPPED = 'folder_tapped';
  static const String PACK_TAPPED = 'pack_tapped';
  static const String SESSION_TAPPED = 'session_tapped';
  static const String AUDIO_STARTED = 'audio_started';
  static const String AUDIO_COMPLETED = 'audio_completed';
  static const String SHORTCUT_TAPPED = 'shortcut_tapped';
  static const String COURSE_TAPPED = 'course_tapped';
  static const String SHARE_TAPPED = 'share_tapped';
  static const String CTA_TAPPED = 'cta_tapped';
  static const String ARTICLE_TAPPED = 'article_tapped';
  static const String SESSION = 'sessions';

  //for audio started
  static const String SESSION_VOICE = 'session_voice';
  static const String SESSION_LENGTH = 'session_length';
  static const String SESSION_TITLE = 'session_title';
  static const String SESSION_ID = 'session_id';
  static const String SESSION_BACKGROUND_SOUND = 'session_background_sound';

  //for cta tapped
  static const String PLAYER_COPY_VERSION = 'player_copy_version';

  static const String DESTINATION = 'destination';
  static const String TYPE = 'type';
  static const String ITEM = 'item';

  static String get url => BASE_URL + 'items/analytics_sessions/';

  static Future<void> trackEvent(Map<String, dynamic> map) async {
    //only track in release mode, not debug
    if (kReleaseMode) {
      unawaited(httpPost(url, await generatedToken, body: map));
    }
  }

  static List<Map<String, String>> destinationData(String type, String item) {
    return [
      {TYPE: type, ITEM: item}
    ];
  }
}

String mapFileTypeToPlural(FileType fileType) {
  switch (fileType) {
    case FileType.folder:
      return 'folders';
      break;
    case FileType.text:
      return 'articles';
      break;
    case FileType.session:
      return 'sessions';
      break;
    case FileType.url:
      return 'urls';
      break;
    case FileType.daily:
      return 'dailies';
      break;
    case FileType.app:
      return 'collection';
      break;
  }
  return '';
}

String mapToPlural(String fileType) {
    if (fileType.contains('folder')) {
      return 'folders';
    }
    if (fileType.contains('articles')) {
      return 'articles';
    }
    if (fileType.contains('session')) {
      return 'sessions';
    }
    if (fileType.contains('url')) {
      return 'urls';
    }
    if (fileType.contains('daily')) {
      return 'dailies';
    }
    return '';
  }