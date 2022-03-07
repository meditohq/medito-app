import 'package:Medito/network/folder/folder_response.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/btm_nav/downloads_widget.dart';
import 'package:Medito/widgets/folders/folder_nav_widget.dart';
import 'package:Medito/widgets/player/player2/player_widget_2.dart';
import 'package:Medito/widgets/session_options/session_options_screen.dart';
import 'package:Medito/widgets/text/text_file_widget.dart';
import 'package:flutter/material.dart';

class NavigationFactory {
  static Future<void> navigate(BuildContext context, Screen key,
      {String id, bool normalPop}) {
    switch (key) {
      case Screen.folder:
        assert(id.isNotEmpty);
        return Navigator.pushNamed(context, FolderNavWidget.routeName,
            arguments: FolderArguments(id));
        break;
      case Screen.player:
        return _push(context, PlayerWidget(normalPop: normalPop));
        break;
      case Screen.article:
        return _push(
            context,
            TextFileWidget(
              id: id,
            ));
        break;
      case Screen.stats:
        // _push(context, StreakWidget());
        break;
      case Screen.session:
        assert(id.isNotEmpty);
        return _push(
            context,
            SessionOptionsScreen(
              id: id,
              screenKey: key,
            ));
        break;
      case Screen.donation:
        break;
      case Screen.collection:
        return _push(context, DownloadsListWidget());
        break;
      case Screen.daily:
        return _push(
            context,
            SessionOptionsScreen(
              id: id,
              screenKey: key,
            ));
        break;
      case Screen.url:
        return launchUrl(id);
        break;
    }

    return null;
  }

  static Future<void> _push(BuildContext context, Widget widget) =>
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => widget,
          ));

  static Screen getScreenFromItemType(FileType fileType) {
    switch (fileType) {
      case FileType.session:
        return Screen.session;
        break;
      case FileType.text:
        return Screen.article;
        break;
      case FileType.folder:
        return Screen.folder;
      case FileType.daily:
        return Screen.daily;
      case FileType.url:
        return Screen.url;
        break;
      case FileType.app:
        Screen.collection;
        break;
    }
    return null;
  }

  static Future<void> navigateToScreenFromString(
      String place, String id, BuildContext context) {
    if (place == 'session') {
      return navigate(context, Screen.session, id: id);
    }
    if (place == 'daily') {
      return navigate(context, Screen.daily, id: id);
    }
    if (place == 'donation') {
      return navigate(context, Screen.donation);
    }
    if (place == 'article') {
      return navigate(context, Screen.article, id: id);
    }
    if (place == 'folder') {
      return navigate(context, Screen.folder, id: id);
    }
    if (place == 'url') {
      return launchUrl(id);
    }
    if(place == 'app'){
      return navigate(context, Screen.collection, id: id);
    }
    return null;
  }
}

enum Screen {
  folder,
  player,
  article,
  stats,
  session,
  daily,
  donation,
  url,
  collection
}
