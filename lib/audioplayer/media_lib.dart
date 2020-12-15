import 'package:Medito/data/attributions_content.dart' as AttContent;
import 'package:Medito/data/page.dart';
import 'package:Medito/viewmodel/model/list_item.dart';
import 'package:audio_service/audio_service.dart';

class MediaLibrary {
  static MediaItem saveMediaLibrary(
      String description,
      String title,
      Files fileTapped,
      Illustration illustration,
      String secondaryColor,
      String primaryColor,
      String bgMusic,
      int durationAsMiliseconds,
      ListItem listItem,
      AttContent.Content attributions) {
    return MediaItem(
      id: fileTapped.url,
      extras: {
        'location': fileTapped.filename,
        'bgMusic': bgMusic,
        'id': listItem.id,
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
      artist: fileTapped.voice,
      artUri: illustration.url,
    );
  }
}
