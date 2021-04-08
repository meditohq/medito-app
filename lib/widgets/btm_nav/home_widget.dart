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
import 'package:Medito/widgets/home/small_shortcuts/small_shortcuts_row_widget.dart';
import 'package:Medito/widgets/packs/announcement_banner_widget.dart';
import 'package:flutter/material.dart';

class HomeWidget extends StatelessWidget {
  final _bloc = HomeBloc();

  @override
  Widget build(BuildContext context) {
    _bloc.fetchMenu();

    return SafeArea(
      child: Scaffold(
        body: ListView(
          children: [
            _getAppBar(context),
            AnnouncementBanner(),
            SmallShortcutsRowWidget(),
            // SmallShortcutsRowWidget()
          ],
        ),
      ),
    );
  }

  AppBar _getAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: MeditoColors.darkMoon,
      elevation: 0,
      title: _getTitleWidget(context),
      actions: <Widget>[
        StreamBuilder<ApiResponse<MenuResponse>>(
            stream: _bloc.menuList.stream,
            initialData: ApiResponse.loading(),
            builder: (context, snapshot) {
              switch (snapshot.data.status) {
                case Status.LOADING:
                  return Container();
                  break;
                case Status.COMPLETED:
                  return _getMenu(context, snapshot);
                  break;
                case Status.ERROR:
                  return Container();
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
                style: Theme.of(context)
                    .textTheme
                    .headline3
                    .copyWith(color: MeditoColors.walterWhite)),
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
            style: Theme.of(context).textTheme.headline5);
      });
}
