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

import 'dart:async';

import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/viewmodel/auth.dart';
import 'package:Medito/widgets/tiles/tile_screen.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'tracking/tracking.dart';
import 'utils/colors.dart';

Future<void> main() async {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarColor: Colors.transparent));
  WidgetsFlutterBinding.ensureInitialized();

  //If these values are missing, just delete this method and initialiseTracker below.
  // But please don't commit to git
  FirebaseApp app = await Firebase.initializeApp(
      options: FirebaseOptions(
    appId: appId,
    apiKey: apiKey,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    databaseURL: databaseURL,
  ));

  InAppPurchaseConnection.enablePendingPurchases();
  Tracking.initialiseTracker(app);

  runApp(HomeScreenWidget());

}

/// This Widget is the main application widget.
class HomeScreenWidget extends StatefulWidget {
  static const String _title = 'Medito';

  @override
  _HomeScreenWidgetState createState() => _HomeScreenWidgetState();
}

class _HomeScreenWidgetState extends State<HomeScreenWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      print("resuming");
      await updateStatsFromBg();
    }
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      initialRoute: '/nav',
      routes: {
        '/nav': (context) => Scaffold(
            appBar: null, //AppBar(title: const Text(_title)),
            body: AudioServiceWidget(child: TileList())),
      },
      theme: ThemeData(
          splashColor: MeditoColors.moonlight,
          canvasColor: MeditoColors.darkMoon,
          pageTransitionsTheme: PageTransitionsTheme(builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: SlideTransitionBuilder(),
          }),
          accentColor: MeditoColors.lightColor,
          textTheme: buildDMSansTextTheme(context)),
      title: HomeScreenWidget._title,
      navigatorObservers: [Tracking.getObserver()],
    );
  }
}

class SlideTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    animation = CurvedAnimation(curve: Curves.easeInOutExpo, parent: animation);

    return SlideTransition(
      position: Tween(begin: Offset(1.0, 0.0), end: Offset(0.0, 0.0))
          .animate(animation),
      child: child,
    );
  }
}
