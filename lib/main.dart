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
import 'package:Medito/widgets/folders/folder_nav_widget.dart';
import 'package:Medito/widgets/packs/packs_screen.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:pedantic/pedantic.dart';

import 'tracking/tracking.dart';
import 'utils/colors.dart';

Future<void> main() async {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarColor: Colors.transparent));
  WidgetsFlutterBinding.ensureInitialized();

  var app = await Firebase.initializeApp(
      options: FirebaseOptions(
    appId: appId,
    apiKey: apiKey,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    databaseURL: databaseURL,
  ));

  await Tracking.initialiseTracker(app);

  InAppPurchaseConnection.enablePendingPurchases();

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
    super.initState();

    isTrackingAccepted().then((value) async {
      if (value) {
        Tracking.enableAnalytics(true);
      } else {
        Tracking.enableAnalytics(false);
      }
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkForUpdate());
      await updateStatsFromBg();
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> checkForUpdate() async {
    unawaited(InAppUpdate.checkForUpdate().then((info) {
      setState(() {
        if (info.flexibleUpdateAllowed && info.updateAvailable) {
          InAppUpdate.startFlexibleUpdate().catchError(_onError);
        }
      });
    }).catchError(_onError));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/main',
      routes: {
        '/': (context) =>
            Scaffold(body: AudioServiceWidget(child: PackListWidget())),
        FolderNavWidget.routeName: (context) => FolderNavWidget()
      },
      theme: ThemeData(
          splashColor: MeditoColors.moonlight,
          canvasColor: MeditoColors.darkMoon,
          pageTransitionsTheme: PageTransitionsTheme(builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: SlideTransitionBuilder(),
          }),
          accentColor: MeditoColors.walterWhite,
          textTheme: buildDMSansTextTheme(context)),
      title: HomeScreenWidget._title,
      navigatorObservers: [Tracking.getObserver()],
    );
  }

  void _onError() {
    print('update error');
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
