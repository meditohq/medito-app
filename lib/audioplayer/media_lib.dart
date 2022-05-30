import 'package:audio_service/audio_service.dart';

class MediaLibrary {
  static MediaItem getMediaLibrary(
      {String description,
      String title,
      String illustrationUrl,
      String secondaryColor,
      String primaryColor,
      int durationAsMilliseconds,
      String fileId,
      String attributions,
      String voice,
      String length,
        bool hasBgSound,
      int sessionId}) {
    return MediaItem(
      id: fileId,
      extras: {
        LOCATION: fileId,
        ID: fileId,
        SESSION_ID: sessionId,
        PRIMARY_COLOUR: primaryColor,
        SECONDARY_COLOUR: secondaryColor,
        ATTR: attributions,
        LENGTH: length,
        DURATION: durationAsMilliseconds,
        HAS_BG_SOUND : hasBgSound,
      },
      artist: voice,
      album: '', //empty to remove it from the notification
      title: title,
      artUri: Uri.parse(illustrationUrl),
    );
  }
}

const String HAS_BG_SOUND = 'hasBgSound';
const String APP_VERSION = 'appVersion';
const String DURATION = 'duration';
const String LENGTH = 'length';
const String ATTR = 'attr';
const String SECONDARY_COLOUR = 'secondaryColor';
const String PRIMARY_COLOUR = 'primaryColor';
const String ID = 'id';
const String SESSION_ID = 'sessionId';
const String SESSION_TITLE = 'sessionTitle';
const String LOCATION = 'location';