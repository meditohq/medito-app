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

import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/home/home_bloc.dart';
import 'package:Medito/network/home/menu_response.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/widgets/home/courses_row_widget.dart';
import 'package:Medito/widgets/home/daily_message_widget.dart';
import 'package:Medito/widgets/home/small_shortcuts_row_widget.dart';
import 'package:Medito/widgets/home/stats_widget.dart';
import 'package:Medito/widgets/packs/announcement_banner_widget.dart';
import 'package:flutter/material.dart';

class HomeWidget extends StatelessWidget {
  final _bloc = HomeBloc();

  final GlobalKey<AnnouncementBannerState> _announceKey = GlobalKey();
  final GlobalKey<SmallShortcutsRowWidgetState> _shortcutKey = GlobalKey();
  final GlobalKey<CoursesRowWidgetState> _coursesKey = GlobalKey();
  final GlobalKey<DailyMessageWidgetState> _dailyMessageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    _bloc.fetchMenu();

    return SafeArea(
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () {
            _announceKey.currentState?.refresh();
            _shortcutKey.currentState?.refresh();
            _coursesKey.currentState?.refresh();
            _dailyMessageKey.currentState?.refresh();
            return _bloc.fetchMenu(skipCache: true);
          },
          child: ListView(
            children: [
              _getAppBar(context),
              AnnouncementBanner(key: _announceKey),
              SmallShortcutsRowWidget(key: _shortcutKey),
              CoursesRowWidget(key: _coursesKey),
              StatsWidget(),
              DailyMessageWidget(key: _dailyMessageKey)
            ],
          ),
        ),
      ),
    );
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
                  return Icon(Icons.more_vert, color: MeditoColors.walterWhite,);
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
      future: _bloc.getTitleText(),
      initialData: 'Medito',
      builder: (context, snapshot) {
        return Text(snapshot.data,
            style: Theme.of(context).textTheme.headline1);
      });
}
