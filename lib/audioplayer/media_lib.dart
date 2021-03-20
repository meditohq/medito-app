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
      String id,
      String attributions}) {
    return MediaItem(
      id: id,
      extras: {
        'location': id,
        'bgMusic': bgMusic,
        'id': id,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'attr': attributions,
        'duration': durationAsMilliseconds,
      },
      album: description,
      title: title,
      artUri: illustrationUrl,
    );
  }
}
