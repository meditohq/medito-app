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
import 'package:Medito/user/user_utils.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/utils/text_themes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/btm_nav/home_widget.dart';
import 'package:Medito/widgets/btm_nav/library_widget.dart';
import 'package:Medito/widgets/folders/folder_nav_widget.dart';
import 'package:Medito/widgets/packs/packs_screen.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'network/downloads/downloads_bloc.dart';
import 'utils/colors.dart';

SharedPreferences sharedPreferences;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Tracking.initialiseTracker();
  sharedPreferences = await SharedPreferences.getInstance();

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
  final _bloc = DownloadsBloc();
  final _messengerKey = GlobalKey<ScaffoldState>();

  var _deletingCache = true;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: MeditoColors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          statusBarColor: MeditoColors.transparent),
    );

    isTrackingAccepted().then((value) async {
      //todo
    });

    checkConnectivity().then((value) {
      if (!value) {
        _onTabTapped(2);
      }
    });

    firstOpenOperations().then((value) {
      setState(() {
        _deletingCache = false;
      });
    });

    // update stats for any sessions that were listened in the background and after the app was killed
    updateStatsFromBg();
    // listened for app background/foreground events
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bloc.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _checkToShowSwipeToDeleteTip(index);
      _currentIndex = index;
    });
  }

  void _checkToShowSwipeToDeleteTip(int index) {
    if (_children[index] is LibraryWidget) {
      DownloadsBloc.fetchDownloads().then((value) {
        if (value.isNotEmpty) {
          showSwipeToDeleteTip();
        }
      });
    }
  }

  void showSwipeToDeleteTip() async {
    await _bloc.seenTip().then((seen) {
      if (!seen) {
        unawaited(_bloc.setSeenTip());
        createSnackBar(SWIPE_TO_DELETE, _messengerKey.currentContext,
            color: MeditoColors.darkMoon);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AudioServiceWidget(
      child: MaterialApp(
        initialRoute: '/nav',
        routes: {
          FolderNavWidget.routeName: (context) => FolderNavWidget(),
          '/nav': (context) => _deletingCache
              ? _getLoadingWidget()
              : Scaffold(
                  key: _messengerKey,
                  body: IndexedStack(
                    index: _currentIndex,
                    children: _children,
                  ),
                  bottomNavigationBar: Container(
                    decoration: BoxDecoration(
                        color: MeditoColors.softGrey,
                        border: Border(
                            top: BorderSide(
                                color: MeditoColors.softGrey, width: 2.0))),
                    child: BottomNavigationBar(
                      selectedLabelStyle: Theme.of(context)
                          .textTheme
                          .headline1
                          .copyWith(fontSize: 12),
                      unselectedLabelStyle: Theme.of(context)
                          .textTheme
                          .headline2
                          .copyWith(fontSize: 12),
                      selectedItemColor: MeditoColors.walterWhite,
                      unselectedItemColor: MeditoColors.newGrey,
                      currentIndex: _currentIndex,
                      onTap: _onTabTapped,
                      items: [
                        BottomNavigationBarItem(
                          tooltip: 'Home',
                          icon: Icon(
                            Icons.home_outlined,
                            size: 20,
                          ),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(
                            Icons.format_list_bulleted_outlined,
                            size: 20,
                          ),
                          tooltip: 'Packs',
                          label: 'Packs',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(
                            Icons.bookmark_border_outlined,
                            size: 20,
                          ),
                          tooltip: 'Library',
                          label: 'Library',
                        ),
                      ],
                    ),
                  ),
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
            textTheme: meditoTextTheme(context)),
        title: ParentWidget._title,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // update session stats when app comes into foreground
      updateStatsFromBg();
    }
  }
}

Widget _getLoadingWidget() {
  return Center(child: CircularProgressIndicator());
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
