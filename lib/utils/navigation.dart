import 'package:Medito/widgets/donation/donation_page.dart';
import 'package:Medito/widgets/folders/folder_nav_widget.dart';
import 'package:Medito/widgets/session_options_screen.dart';
import 'package:Medito/widgets/streak_page.dart';
import 'package:flutter/material.dart';

class NavigationFactory {
  static void navigate(BuildContext context, Screen key, {String id}) {
    switch (key) {
      case Screen.folder:
        assert(id.isNotEmpty);
        _push(context, FolderNavWidget(contentId: id));
        break;
      case Screen.player:
      //
        break;
      case Screen.text:
      // TODO: Handle this case.
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
    }
  }

  static void _push(BuildContext context, Widget widget) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => widget,
        ));
  }

  static Screen getScreenFromString(String string) {
    switch (string) {
      case 'folder':
        return Screen.folder;
      case 'session':
        return Screen.session_options;
      case 'article':
        return Screen.text;
      default:
        return null;
    }
  }
}

enum Screen { folder, player, text, stats, session_options, donation }