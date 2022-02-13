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

import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/downloads/downloads_bloc.dart';
import 'package:Medito/network/home/home_bloc.dart';
import 'package:Medito/network/home/home_repo.dart';
import 'package:Medito/network/home/menu_response.dart';
import 'package:Medito/network/user/user_utils.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/home/courses_row_widget.dart';
import 'package:Medito/widgets/home/daily_message_widget.dart';
import 'package:Medito/widgets/home/small_shortcuts_row_widget.dart';
import 'package:Medito/widgets/home/stats_widget.dart';
import 'package:Medito/widgets/packs/announcement_banner_widget.dart';
import 'package:Medito/widgets/packs/error_widget.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info/package_info.dart';
import 'package:pedantic/pedantic.dart';
import 'package:share/share.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeWidget extends StatefulWidget {
  const HomeWidget(this.hasOpened);

  final bool hasOpened;

  @override
  _HomeWidgetState createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> {
  final _bloc = HomeBloc(repo: HomeRepo());

  final GlobalKey<AnnouncementBannerState> _announceKey = GlobalKey();

  final GlobalKey<SmallShortcutsRowWidgetState> _shortcutKey = GlobalKey();

  final GlobalKey<CoursesRowWidgetState> _coursesKey = GlobalKey();

  final GlobalKey<DailyMessageWidgetState> _dailyMessageKey = GlobalKey();

  StreamSubscription<ConnectivityResult> subscription;

  @override
  Widget build(BuildContext context) {
    _observeNetwork();

    _bloc.fetchMenu();
    _bloc.checkConnection();

    return SafeArea(
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () {
            return _refresh();
          },
          child: StreamBuilder<bool>(
              stream: _bloc.connectionStreamController.stream,
              builder: (context, connectionSnapshot) {
                if (connectionSnapshot.hasData && !connectionSnapshot.data) {
                  return _buildErrorPacksWidget();
                } else {
                  return ListView(
                    physics: AlwaysScrollableScrollPhysics(),
                    children: [
                      _getAppBar(context),
                      AnnouncementBanner(key: _announceKey, hasOpened: widget.hasOpened),
                      SmallShortcutsRowWidget(
                        key: _shortcutKey,
                        onTap: (type, id) => _navigate(
                            type, id, context, Tracking.SHORTCUT_TAPPED),
                      ),
                      CoursesRowWidget(
                          key: _coursesKey,
                          onTap: (type, id) => _navigate(
                              type, id, context, Tracking.COURSE_TAPPED)),
                      StatsWidget(),
                      SizedBox(height: 16),
                      DailyMessageWidget(key: _dailyMessageKey),
                      SizedBox(height: 24)
                    ],
                  );
                }
              }),
        ),
      ),
    );
  }

  Column _buildErrorPacksWidget() => Column(
        children: [
          _getAppBar(context),
          Expanded(child: ErrorPacksWidget(onPressed: () => _refresh())),
        ],
      );

  Future<void> _navigate(type, id, BuildContext context, String origin) {
    return checkConnectivity().then(
      (value) {
        if (value) {
          return NavigationFactory.navigateToScreenFromString(type, id, context)
              .then((value) {
            return _refresh();
          });
        } else {
          _bloc.checkConnection();
        }
      },
    );
  }

  Future<void> _refresh() {
    _bloc.checkConnection();
    _announceKey.currentState?.refresh();
    _shortcutKey.currentState?.refresh();
    _coursesKey.currentState?.refresh();
    _dailyMessageKey.currentState?.refresh();
    return _bloc.fetchMenu(skipCache: true);
  }

  AppBar _getAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: MeditoColors.darkMoon,
      elevation: 0,
      actionsIconTheme: IconThemeData(color: MeditoColors.walterWhite),
      title: _getTitleWidget(context),
      actions: <Widget>[
        StreamBuilder<ApiResponse<MenuResponse>>(
            stream: _bloc.menuList.stream,
            initialData: ApiResponse.completed(MenuResponse(data: [])),
            builder: (context, snapshot) {
              switch (snapshot.data.status) {
                case Status.LOADING:
                case Status.ERROR:
                  return GestureDetector(
                    onTap: () => _bloc.fetchMenu(skipCache: true),
                    child: Icon(
                      Icons.more_vert,
                      color: MeditoColors.walterWhite,
                    ),
                  );
                case Status.COMPLETED:
                  return _getMenu(context, snapshot);
                  break;
              }
              return Container();
            }),
      ],
    );
  }

  PopupMenuButton<MenuData> _getMenu(
      BuildContext context, AsyncSnapshot<ApiResponse<MenuResponse>> snapshot) {
    return PopupMenuButton<MenuData>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
      ),
      color: MeditoColors.deepNight,
      onSelected: (MenuData result) {
        NavigationFactory.navigateToScreenFromString(
            result.itemType, result.itemPath, context);
      },
      itemBuilder: (BuildContext context) {
        return snapshot.data.body.data.map((MenuData data) {
          return PopupMenuItem<MenuData>(
            value: data,
            child: Text(data.itemLabel,
                style: Theme.of(context).textTheme.headline4),
          );
        }).toList();
      },
    );
  }

  Widget _getTitleWidget(BuildContext context) => FutureBuilder<String>(
      future: _bloc.getTitleText(DateTime.now()),
      initialData: 'Medito',
      builder: (context, snapshot) {
        return GestureDetector(
          onLongPress: () => _showVersionPopUp(context),
          child:
              Text(snapshot.data, style: Theme.of(context).textTheme.headline1),
        );
      });

  Future<void> _showVersionPopUp(BuildContext context) async {
    var packageInfo = await PackageInfo.fromPlatform();

    var version = packageInfo.version;
    var buildNumber = packageInfo.buildNumber;

    var line1 =
        'Version: $version - Build Number: $buildNumber - ReleaseMode: $kReleaseMode';

    var prefs = await SharedPreferences.getInstance();
    var userID = prefs.getString(USER_ID) ?? 'None';
    final snackBar = SnackBar(
        content: GestureDetector(
          onTap: () {
            Share.share('$line1 $userID');
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line1, style: TextStyle(color: MeditoColors.meditoTextGrey)),
              Text(userID, style: TextStyle(color: MeditoColors.meditoTextGrey))
            ],
          ),
        ),
        backgroundColor: MeditoColors.midnight);

    // Find the Scaffold in the Widget tree and use it to show a SnackBar!
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void dispose() {
    super.dispose();
    subscription.cancel();
    _bloc.dispose();
  }

  void _observeNetwork() {
    subscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      _refresh();
    });
  }

  void showSwipeToDeleteTip() async {
    await DownloadsBloc.seenTip().then((seen) {
      if (!seen) {
        unawaited(DownloadsBloc.setSeenTip());
        createSnackBar(SWIPE_TO_DELETE, context, color: MeditoColors.darkMoon);
      }
    });
  }
}
