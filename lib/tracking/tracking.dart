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
import 'package:Medito/user/user_utils.dart';
import 'package:Medito/viewmodel/auth.dart';
import 'package:Medito/viewmodel/http_get.dart';
import 'package:flutter/foundation.dart';
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
  static const String SESSION = 'session';

  //for audio started
  static const String SESSION_VOICE = 'session_voice';
  static const String SESSION_LENGTH = 'session_length';
  static const String SESSION_BACKGROUND_SOUND = 'session_background_sound';

  //for cta tapped
  static const String PLAYER_COPY_VERSION = 'player_copy_version';

  static const String DESTINATION = 'destination';
  static const String TYPE = 'type';
  static const String ITEM = 'item';

  static String get url => baseUrl + 'items/actions/';

  static Future<void> trackEvent(Map<String, dynamic> map) async {
    //only track in release mode, not debug
    if (!kReleaseMode) {
      unawaited(httpPost(url, body: map, token: await token));
    }
  }

  static List<Map<String, String>> destinationData(String type, String item) {
    return [
      {TYPE: type, ITEM: item}
    ];
  }
}
