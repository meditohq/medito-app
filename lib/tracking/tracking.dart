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
import 'package:Medito/utils/utils.dart';
import 'package:flutter/foundation.dart' as foundation;

class Tracking {
  static const String SCREEN_LOADED = 'screen_loaded';
  static const String FILE_TAPPED = 'file_tapped';
  static const String CTA_TAPPED = 'cta_tapped';
  static const String MAIN_CTA_TAPPED = 'main_cta_tapped';
  static const String SECOND_CTA_TAPPED = 'share_tapped';
  static const String TILE = 'tile';
  static const String TAP = 'tap';

  static const String AUDIO_DOWNLOAD = 'audio_download';
  static const String AUDIO_COMPLETED = 'audio_completed';
  static const String AUDIO_COMPLETED_BUTTON_TAPPED =
      'audio_completed_button_tapped';

  static const String PLAYER_PAGE = 'player_page';
  static const String PLAYER_END_PAGE = 'player_end_page';
  static const String FOLDER_PAGE = 'folder_page';
  static const String DONATION_PAGE_1 = 'donation_page_1';
  static const String DONATION_PAGE_2 = 'donation_page_2';
  static const String DONATION_PAGE_3 = 'donation_page_3';
  static const String DOWNLOAD_PAGE = 'download_page';
  static const String TEXT_PAGE = 'text_page';
  static const String STREAK_PAGE = 'streak_page';

  static const String TILE_TAPPED = 'tile_tapped';
  static const String TRACKING_TAPPED = 'tracking_tapped';
  static const String TEXT_TAPPED = 'text_tapped';
  static const String FOLDER_TAPPED = 'folder_tapped';
  static const String SESSION_TAPPED = 'session_tapped';
  static const String PLAY_TAPPED = 'play_tapped';

  static const String HOME = 'home_page';

  static const String _dbName = foundation.kReleaseMode ? 'donations' : 'test';

  static Future<void> initialiseTracker() async {}

  static void changeScreenName(String screenName) {}

  // like 'LoginWidget', 'Login button', 'Clicked'
  static Future<void> trackEvent(
      String eventName, String action, String destination,
      {Map<String, String> map}) async {
    var accepted = await isTrackingAccepted();

    if (foundation.kReleaseMode && accepted) {
      //only track in release mode, not debug

      var defaultMap = <String, String>{
        'action': action.clean(),
        'destination': destination.clean(),
      };
      if (map != null) defaultMap.addAll(map);

      print('Event logged: $eventName');
    }
  }

}

extension on String {
  String clean() {
    var str = replaceAll('/', '_').replaceAll('-', '_');

    if (str.isNotEmpty && !str.startsWith(RegExp(r'[A-Za-z]'))) {
      str.replaceRange(0, 1, '');
    }

    return str;
  }
}
