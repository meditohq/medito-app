import 'package:Medito/network/folder/folder_items.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/donation/donation_page.dart';
import 'package:Medito/widgets/downloads/downloads_widget.dart';
import 'package:Medito/widgets/folders/folder_nav_widget.dart';
import 'package:Medito/widgets/player/player_widget.dart';
import 'package:Medito/widgets/sessionoptions/session_options_screen.dart';
import 'package:Medito/widgets/streak_widgets/streak_page.dart';
import 'package:Medito/widgets/text/text_file_widget.dart';
import 'package:flutter/material.dart';

class NavigationFactory {
  static void navigate(BuildContext context, Screen key, {String id, bool normalPop}) {
    switch (key) {
      case Screen.folder:
        assert(id.isNotEmpty);
        Navigator.pushNamed(context, FolderNavWidget.routeName,
            arguments: FolderArguments(id));
        break;
      case Screen.player:
        _push(context, PlayerWidget(normalPop: normalPop));
        break;
      case Screen.text:
        _push(
            context,
            TextFileWidget(
              id: id,
            ));
        break;
      case Screen.stats:
        _push(context, StreakWidget());
        break;
      case Screen.session_options:
        assert(id.isNotEmpty);
        _push(context, SessionOptionsScreen(id: id));
        break;
      case Screen.donation:
        _push(context, DonationWidget());
        break;
      case Screen.downloads:
        _push(context, DownloadsListWidget());
        break;
    }
  }

  static void _push(BuildContext context, Widget widget) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => widget,
        ));
  }

  static Screen getScreenFromItemType(FileType fileType) {
    switch (fileType) {
      case FileType.session:
        return Screen.session_options;
        break;
      case FileType.text:
        return Screen.text;
        break;
      case FileType.folder:
        return Screen.folder;
      case FileType.url:
        throw Exception('No screen type for URL');
    }
    return null;
  }

  static void navigateToScreenFromString(
      String place, String id, BuildContext context) {
    if (place == 'session') {
      navigate(context, Screen.session_options, id: id);
    }
    if (place == 'donation') {
      navigate(context, Screen.donation);
    }
    if (place == 'article') {
      navigate(context, Screen.text, id: id);
    }
    if (place == 'download') {
      navigate(context, Screen.downloads);
    }
    if (place == 'folder') {
      navigate(context, Screen.folder, id: id);
    }
    if (place == 'url') {
      launchUrl(id);
    }
  }
}

enum Screen {
  folder,
  player,
  text,
  stats,
  session_options,
  donation,
  downloads
}
