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

import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/viewmodel/auth.dart';
import 'package:Medito/widgets/btm_nav/home_widget.dart';
import 'package:Medito/widgets/btm_nav/library_widget.dart';
import 'package:Medito/widgets/folders/folder_nav_widget.dart';
import 'package:Medito/widgets/packs/packs_screen.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

Future<void> main() async {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
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

  runApp(ParentWidget());
}

/// This Widget is the main application widget.
class ParentWidget extends StatefulWidget {
  static const String _title = 'Medito';

  @override
  _ParentWidgetState createState() => _ParentWidgetState();
}

class _ParentWidgetState extends State<ParentWidget>
    with WidgetsBindingObserver {
  var _currentIndex = 0;
  final _children = [HomeWidget(), PackListWidget(), LibraryWidget()];

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
  Widget build(BuildContext context) {
    return AudioServiceWidget(
      child: MaterialApp(
        initialRoute: '/nav',
        routes: {
          FolderNavWidget.routeName: (context) => FolderNavWidget(),
          '/nav': (context) => Scaffold(
                body: _children[_currentIndex], // new
                bottomNavigationBar: BottomNavigationBar(
                  selectedLabelStyle: Theme.of(context).textTheme.headline6,
                  unselectedLabelStyle: Theme.of(context)
                      .textTheme
                      .headline6
                      .copyWith(color: MeditoColors.newGrey),
                  currentIndex: _currentIndex,
                  onTap: onTabTapped,
                  items: [
                    BottomNavigationBarItem(
                      icon: Container(),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Container(),
                      label: 'Packs',
                    ),
                    BottomNavigationBarItem(
                      icon: Container(),
                      label: 'Library',
                    ),
                  ],
                ),
                appBar: null, //AppBar(title: const Text(_title)),
              )
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
        title: ParentWidget._title,
        navigatorObservers: [Tracking.getObserver()],
      ),
    );
  }

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
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
