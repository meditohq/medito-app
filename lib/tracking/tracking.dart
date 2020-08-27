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

class Tracking {
  static const String SCREEN_LOADED = "screen loaded ";
  static const String FOLDER_TAPPED = "folder tapped ";
  static const String FILE_TAPPED = "file tapped ";
  static const String PLAYER_TAPPED = "player tapped ";
  static const String BOTTOM_SHEET = "bottom sheet open ";
  static const String READ_MORE_TAPPED = "read more tapped ";
  static const String BREADCRUMB = "breadcrumb ";
  static const String TILE = "tile ";
  static const String PLAYER = "player ";

  static const String AUDIO_DOWNLOAD = "audio download ";
  static const String AUDIO_PLAY = "audio started ";
  static const String AUDIO_ERROR = "audio error ";
  static const String AUDIO_REWIND = "audio rewind ";
  static const String AUDIO_FF = "audio forward ";
  static const String AUDIO_RESUME = "audio reumed ";
  static const String AUDIO_STOPPED = "audio stopped ";
  static const String AUDIO_PAUSED = "audio paused ";
  static const String AUDIO_COMPLETED = "audio completed ";
  static const String AUDIO_SEEK = "audio seek to ";

  static const String AUDIO_OPENED = "audio opened. ";
  static const String FOLDER_OPENED = "folder opened. ";
  static const String TEXT_ONLY_OPENED = "text only opened. ";
  static const String AUDIO_AND_TEXT_OPENED = "audio and text file opened. ";
  static const String CURRENTLY_SELECTED_FILE = "current file. ";

  static const String BREADCRUMB_TAPPED = "breadcrumb tapped. ";
  static const String PLAYER_BREADCRUMB_TAPPED = "close player. ";
  static const String TILE_TAPPED = "tile tapped. ";
  static const String FINDER = "finder widget. ";
  static const String HOME = "home page. ";
  static const String APP_CLOSED = "app closed. ";
  static const String BACK_PRESSED = "back pressed. ";

  static Future<void> initialiseTracker() async {
//    await FlutterMatomo.initializeTracker(
//        'https://medito.app/analytics/piwik.php', 1);
  }

  // like "LoginWidget", "Login button", "Clicked"
  static Future<void> trackEvent(
      String widgetName, String eventName, String action) async {
//    await FlutterMatomo.trackEventWithName(widgetName, eventName, action);
  }
}
