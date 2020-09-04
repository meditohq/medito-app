/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/tiles/tile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tracking/tracking.dart';
import 'utils/colors.dart';

Future<void> main() async {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark, statusBarColor: Colors.transparent));
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
      initialRoute: '/nav',
      routes: {
        '/nav': (context) => Scaffold(
            appBar: null, //AppBar(title: const Text(_title)),
            body: TileList()),
      },
      theme: ThemeData(
          canvasColor: MeditoColors.almostBlack,
          pageTransitionsTheme: PageTransitionsTheme(builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: FadeTransitionBuilder(),
          }),
          accentColor: MeditoColors.lightColor,
          textTheme: buildDMSansTextTheme(context)),
      title: _title,
      navigatorObservers: [Tracking.getObserver()],
    );
  }
}

class FadeTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
        child: child);
  }
}
