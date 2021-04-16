import 'package:audio_service/audio_service.dart';

class MediaLibrary {
  static MediaItem getMediaLibrary(
      {String description,
      String title,
      String illustrationUrl,
      String secondaryColor,
      String primaryColor,
      String bgMusic,
      int durationAsMilliseconds,
      String fileId,
      String attributions,
      String voice,
      String length,
      int sessionId}) {
    return MediaItem(
      id: fileId,
      extras: {
        'location': fileId,
        'bgMusic': bgMusic,
        'id': fileId,
        'sessionId': sessionId,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'attr': attributions,
        'length': length,
        'duration': durationAsMilliseconds,
      },
      artist: voice,
      album: description,
      title: title,
      artUri: illustrationUrl,
    );
  }
}
