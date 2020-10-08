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
      Illustration illustration,
      String secondaryColor,
      String primaryColor,
      String bgMusic,
      ListItem listItem,
      AttContent.Content attributions) async {
    var prefs = await SharedPreferences.getInstance();

    await prefs.setString("description", description ?? " ");
    await prefs.setString("audiotitle", title);
    await prefs.setString("fileTapped", json.encode(fileTapped.toJson()));
    await prefs.setString("illustration", json.encode(illustration.toJson()));
    await prefs.setString("secondaryColor", secondaryColor);
    await prefs.setString("primaryColor", primaryColor);
    await prefs.setString("bgMusic", bgMusic);
    await prefs.setString("listItemToListen", json.encode(listItem.toJson()));
    await prefs.setString("attrTitle", attributions.title);
    await prefs.setString("attrLicence", attributions.licenseName);
    await prefs.setString("attrLinkSource", attributions.sourceUrl);
    await prefs.setString("attrLinkLicense", attributions.licenseUrl);
    return;
  }

  static Future<MediaItem> retrieveMediaLibrary() async {
    var prefs = await SharedPreferences.getInstance();

    var description = prefs.getString("description");
    var title = prefs.getString("audiotitle");

    String illustrationAsString = prefs.getString("illustration");
    var illustration = Illustration.fromJson(json.decode(illustrationAsString));

    String bgMusic = prefs.getString("bgMusic");
    String primaryColor = prefs.getString("primaryColor");
    String secondaryColor = prefs.getString("secondaryColor");

    String attrTitle = prefs.getString("attrTitle");
    String attrLicenseName = prefs.getString("attrLicence");
    String attrLinkSource = prefs.getString("attrLinkSource");
    String attrLinkLicense = prefs.getString("attrLinkLicense");

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
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'attrTitle': attrTitle ,
        'attrName' : attrLicenseName,
        'attrLinkSource': attrLinkSource,
        'attrLinkLicense': attrLinkLicense,
      },
      album: description,
      title: title,
      artist: fileTapped.voice,
      artUri: illustration.url,
    );
  }
}
