import 'package:Medito/data/attributions_content.dart' as AttContent;
import 'package:Medito/data/page.dart';
import 'package:audio_service/audio_service.dart';

class MediaLibrary {
  static MediaItem saveMediaLibrary(
      String description,
      String title,
      Illustration illustration,
      String secondaryColor,
      String primaryColor,
      String bgMusic,
      int durationAsMiliseconds,
      String id,
      AttContent.Content attributions) {
    return MediaItem(
      id: id,
      extras: {
        'location': id,
        'bgMusic': bgMusic,
        'id': id,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'attrTitle': attributions.title,
        'attrName': attributions.licenseName,
        'attrLinkSource': attributions.sourceUrl,
        'attrLinkLicense': attributions.licenseUrl,
        'duration': durationAsMiliseconds,
      },
      album: description,
      title: title,
      artUri: illustration.url,
    );
  }
}
