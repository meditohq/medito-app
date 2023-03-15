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
import 'package:Medito/network/auth.dart';
import 'package:Medito/network/folder/folder_response.dart';
import 'package:Medito/network/http_get.dart';
import 'package:Medito/network/user/user_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info/package_info.dart';
import 'package:pedantic/pedantic.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
  static const String SESSION_GUIDE = 'session_guide';
  static const String SESSION_DURATION = 'session_duration';
  static const String SESSION_TITLE = 'session_title';
  static const String SESSION_ID = 'session_id';
  static const String SESSION_BACKGROUND_SOUND = 'session_background_sound';

  //for cta tapped
  static const String PLAYER_COPY_VERSION = 'player_copy_version';

  static const String DESTINATION = 'destination';
  static const String TYPE = 'type';
  static const String APP_VERSION = 'app_version';
  static const String ITEM = 'item';

  static List<Map<String, String>> destinationData(String type, String item) {
    return [
      {TYPE: type, ITEM: item}
    ];
  }

  static Future<void> postUsage(String type,
      [Map<String, String> body = const {}]) async {
    if (kReleaseMode) {
      var packageInfo = await PackageInfo.fromPlatform();
      var version = packageInfo.buildNumber;
      var deviceInfo = await getDeviceDetails();

      var ext = 'items/usage/';
      var url = BASE_URL + ext;
      try {
        var token = await generatedToken;
        if (token != null) {
          unawaited(
            httpPost(
              url,
              token,
              body: {
                Tracking.APP_VERSION: version,
                Tracking.TYPE: type,
              }
                ..addAll(deviceInfo)
                ..addAll(body),
            ),
          );
        }
      } catch (e, str) {
        unawaited(
            Sentry.captureException(e, stackTrace: str, hint: '_postUsage'));
        print('post usage failed: ' + e.toString());
        return;
      }
    }
  }
}

String mapFileTypeToPlural(FileType fileType) {
  switch (fileType) {
    case FileType.folder:
      return 'folders';
    case FileType.text:
      return 'articles';
    case FileType.session:
      return 'sessions';
    case FileType.url:
      return 'urls';
    case FileType.daily:
      return 'dailies';
    case FileType.app:
      return 'collection';
  }
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