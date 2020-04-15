import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/tiles/tile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tracking/tracking.dart';
import 'utils/colors.dart';

Future<void> main() async {
  SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  WidgetsFlutterBinding.ensureInitialized();
  runApp(HomeScreenWidget());
  Tracking.initialiseTracker();
}

/// This Widget is the main application widget.
class HomeScreenWidget extends StatelessWidget {
  static const String _title = 'Medito';

  @override
  Widget build(BuildContext context) {
    Tracking.trackEvent(Tracking.HOME, Tracking.SCREEN_LOADED, '');

    return MaterialApp(
      theme: ThemeData(
          canvasColor: MeditoColors.almostBlack,
          pageTransitionsTheme: PageTransitionsTheme(builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: FadeTransitionBuilder(),
          }),
          accentColor: MeditoColors.lightColor,
          textTheme: buildDMSansTextTheme(context)),
      title: _title,
      home: Scaffold(
          appBar: null, //AppBar(title: const Text(_title)),
          body: TileList()),
    );
  }
}

class FadeTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
        child: child);
  }
}
