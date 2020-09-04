import 'dart:async';
import 'dart:convert';

import 'package:Medito/data/attributions_content.dart' as AttContent;
import 'package:Medito/data/page.dart';
import 'package:Medito/viewmodel/model/list_item.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaLibrary {
  static void saveMediaLibrary(
      String description,
      String title,
      Files fileTapped,
      CoverArt coverArt,
      String textColor,
      coverColor,
      String bgMusic,
      ListItem listItem,
      AttContent.Content attributions) async {
    var prefs = await SharedPreferences.getInstance();

    prefs.setString("description", description ?? " ");
    prefs.setString("audiotitle", title);
    prefs.setString("fileTapped", json.encode(fileTapped.toJson()));
    prefs.setString("coverArt", json.encode(coverArt.toJson()));
    prefs.setString("textColor", textColor);
    prefs.setString("bgMusic", bgMusic);
    prefs.setString("listItemToListen", json.encode(listItem.toJson()));
    prefs.setString("attr", json.encode(attributions.toJson()));
  }

  static Future<MediaItem> retrieveMediaLibrary() async {
    var prefs = await SharedPreferences.getInstance();

    var description = prefs.getString("description");
    var title = prefs.getString("audiotitle");

    String coverArtString = prefs.getString("coverArt");
    var coverArt = CoverArt.fromJson(json.decode(coverArtString));

    String bgMusic = prefs.getString("bgMusic");

    Files fileTapped =
        Files.fromJson(json.decode(prefs.getString("fileTapped")));

    var location = fileTapped.filename;
    var listItemString = prefs.getString("listItemToListen");
    var jsonItem = json.decode(listItemString);
    ListItem listItem = ListItem.fromJson(jsonItem);
    var id = listItem.id;

//    prefs.getString("attr");

    return MediaItem(
      id: fileTapped.url,
      extras: {'location': '$location', 'bgMusic': '$bgMusic', 'id': '$id'},
      album: description,
      title: title,
      artist: fileTapped.voice,
      artUri: coverArt.url,
    );
  }
}
