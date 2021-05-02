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
      int sessionId,
      String bgMusicTitle,
      int bgMusicId}) {
    return MediaItem(
      id: fileId,
      extras: {
        'location': fileId,
        'bgMusic': bgMusic,
        'bgMusicId': bgMusicId,
        'bgMusicTitle': bgMusicTitle,
        'id': fileId,
        'sessionId': sessionId,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'attr': attributions,
        'length': length,
        'duration': durationAsMilliseconds,
      },
      artist: voice,
      album: '',
      title: title,
      artUri: Uri.parse(illustrationUrl),
    );
  }
}
