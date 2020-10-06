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
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/foundation.dart' as Foundation;

class Tracking {
  static const String SCREEN_LOADED = "screen_loaded";
  static const String FOLDER_TAPPED = "folder_tapped";
  static const String FILE_TAPPED = "file_tapped";
  static const String PLAYER_TAPPED = "player_tapped";
  static const String BUTTON_TAPPED = "button_tapped";
  static const String SHARE_BUTTON_TAPPED = "share_button_tapped";
  static const String BOTTOM_SHEET = "bottom_sheet_open";
  static const String READ_MORE_TAPPED = "read_more_tapped";
  static const String BREADCRUMB = "breadcrumb";
  static const String TILE = "tile";
  static const String PLAYER = "player";

  static const String AUDIO_DOWNLOAD = "audio_download";
  static const String AUDIO_PLAY = "audio_started";
  static const String AUDIO_ERROR = "audio_error";
  static const String AUDIO_REWIND = "audio_rewind";
  static const String AUDIO_FF = "audio_forward";
  static const String AUDIO_RESUME = "audio_resumed";
  static const String AUDIO_STOPPED = "audio_stopped";
  static const String AUDIO_PAUSED = "audio_paused";
  static const String AUDIO_COMPLETED = "audio_completed";
  static const String AUDIO_COMPLETED_BUTTON_TAPPED =
      "audio_completed_button_tapped";
  static const String AUDIO_SEEK = "audio_seek_to";

  static const String AUDIO_OPENED = "audio_opened";
  static const String FOLDER_OPENED = "folder_opened";
  static const String TEXT_ONLY_OPENED = "text_only_opened";
  static const String AUDIO_AND_TEXT_OPENED = "audio_and_text_file_opened";
  static const String CURRENTLY_SELECTED_FILE = "current file. ";

  static const String BREADCRUMB_TAPPED = "breadcrumb_tapped";
  static const String PLAYER_BREADCRUMB_TAPPED = "close_player";
  static const String TILE_TAPPED = "tile_tapped";
  static const String FINDER = "finder_widget";
  static const String HOME = "home_page";
  static const String APP_CLOSED = "app_closed";
  static const String BACK_PRESSED = "back_pressed";
  static FirebaseAnalytics _firebaseAnalytics;
  static FirebaseAnalyticsObserver _firebaseAnalyticsObserver;

  static Future<void> initialiseTracker() async {
    _firebaseAnalytics = FirebaseAnalytics();
    _firebaseAnalyticsObserver =
        FirebaseAnalyticsObserver(analytics: _firebaseAnalytics);

    //dummy event
    _firebaseAnalytics.logEvent(
      name: "tracker_initialized",
      parameters: {},
    ).then((value) => print('tracking initialized'));
  }

  static FirebaseAnalyticsObserver getObserver() => _firebaseAnalyticsObserver;

  // like "LoginWidget", "Login button", "Clicked"
  static Future<void> trackEvent(String eventName, String param1, String param2,
      {Map<String, String> map}) async {
    if (Foundation.kReleaseMode) {
      //only track in release mode, not debug

      Map<String, String> defaultMap = {
        "event_info": param1,
        "action": param2,
      };
      if (map != null) defaultMap.addAll(map);

      _firebaseAnalytics.logEvent(
        name: eventName,
        parameters: defaultMap,
      );

      print("Event logged: $eventName");
    }
  }
}
