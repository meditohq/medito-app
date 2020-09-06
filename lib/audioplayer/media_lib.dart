import 'dart:async';
import 'dart:convert';

import 'package:Medito/data/attributions_content.dart' as AttContent;
import 'package:Medito/data/page.dart';
import 'package:Medito/viewmodel/model/list_item.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaLibrary {
  static Future<void> saveMediaLibrary(
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

    await prefs.setString("description", description ?? " ");
    await prefs.setString("audiotitle", title);
    await prefs.setString("fileTapped", json.encode(fileTapped.toJson()));
    await prefs.setString("coverArt", json.encode(coverArt.toJson()));
    await prefs.setString("textColor", textColor);
    await prefs.setString("coverColor", coverColor);
    await prefs.setString("bgMusic", bgMusic);
    await prefs.setString("listItemToListen", json.encode(listItem.toJson()));
    await prefs.setString("attrTitle", attributions.title);
    await prefs.setString("attrLicence", attributions.licenseName);
    return;
  }



  static Future<MediaItem> retrieveMediaLibrary() async {
    var prefs = await SharedPreferences.getInstance();

    var description = prefs.getString("description");
    var title = prefs.getString("audiotitle");

    String coverArtString = prefs.getString("coverArt");
    var coverArt = CoverArt.fromJson(json.decode(coverArtString));

    String bgMusic = prefs.getString("bgMusic");
    String coverColor = prefs.getString("coverColor");
    String textColor = prefs.getString("textColor");

    String attrTitle = prefs.getString("attrTitle");
    String attrLicenseName = prefs.getString("attrLicence");

    Files fileTapped =
        Files.fromJson(json.decode(prefs.getString("fileTapped")));

    var location = fileTapped.filename;
    var listItemString = prefs.getString("listItemToListen");
    var jsonItem = json.decode(listItemString);
    ListItem listItem = ListItem.fromJson(jsonItem);
    var id = listItem.id;

    return MediaItem(
      id: fileTapped.url,
      extras: {
        'location': '$location',
        'bgMusic': '$bgMusic',
        'id': '$id',
        'coverColor': coverColor,
        'textColor': textColor,
        'attr': 'By $attrTitle under $attrLicenseName'
      },
      album: description,
      title: title,
      artist: fileTapped.voice,
      artUri: coverArt.url,
    );
  }
}
