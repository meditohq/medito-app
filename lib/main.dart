import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/main_nav.dart';
import 'package:Medito/widgets/tiles/tile_screen.dart';
import 'package:flutter/material.dart';

import 'tracking/tracking.dart';
import 'utils/colors.dart';

Future<void> main() async {
  runApp(HomeScreenWidget());
  Tracking.initialiseTracker();
}

/// This Widget is the main application widget.
class HomeScreenWidget extends StatelessWidget {
  static const String _title = 'Medito';

  @override
  Widget build(BuildContext context) {
    Tracking.trackScreen(Tracking.HOME, Tracking.SCREEN_LOADED);

    return MaterialApp(
      theme: ThemeData(
          accentColor: MeditoColors.lightColor,
          textTheme: buildDMSansTextTheme(context)),
      title: _title,
      home: Scaffold(
          appBar: null, //AppBar(title: const Text(_title)),
          body: TileList()),
//          body: MainWidget()),
    );
  }
}
