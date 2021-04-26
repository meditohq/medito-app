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
import 'package:Medito/network/packs/packs_bloc.dart';
import 'package:Medito/network/packs/packs_response.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/packs/error_widget.dart';
import 'package:Medito/widgets/packs/pack_list_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PackListWidget extends StatefulWidget {
  PackListWidget({Key key}) : super(key: key);

  @override
  PackListWidgetState createState() {
    return PackListWidgetState();
  }
}

class PackListWidgetState extends State<PackListWidget> {
  PacksBloc _packsBloc;

  @override
  void initState() {
    Tracking.changeScreenName(Tracking.HOME);

    super.initState();
    _packsBloc = PacksBloc();
    _packsBloc.fetchPacksList(true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: SafeArea(
        bottom: false,
        child: _streamBuilderWidget(),
      ),
    );
  }

  Widget _streamBuilderWidget() {
    return FutureBuilder<bool>(
        future: checkConnectivity(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data) {
            return RefreshIndicator(
              displacement: 80,
              color: MeditoColors.walterWhite,
              backgroundColor: MeditoColors.moonlight,
              onRefresh: () => _packsBloc.fetchPacksList(true),
              child: StreamBuilder<ApiResponse<List<PacksData>>>(
                  stream: _packsBloc.packsListController.stream,
                  initialData: ApiResponse.loading(),
                  builder: (context, snapshot) {
                    return FutureBuilder<bool>(
                        future: checkConnectivity(),
                        builder: (context, connectionSnapshot) {
                          if (!connectionSnapshot.hasData) {
                            return getLoadingWidget();
                          } else if (connectionSnapshot.hasData &&
                              connectionSnapshot.data) {
                            return _getViewMainContent(snapshot);
                          } else {
                            return _getErrorPacksWidget();
                          }
                        });
                  }),
            );
          } else {
            return _getErrorPacksWidget();
          }
        });
  }

  Widget _getViewMainContent(
      AsyncSnapshot<ApiResponse<List<PacksData>>> snapshot) {
    if (snapshot.hasData) {
      switch (snapshot.data.status) {
        case Status.LOADING:
          return getLoadingWidget();
        case Status.COMPLETED:
          return _getListWidget(snapshot.data.body);
        case Status.ERROR:
          return _getErrorPacksWidget();
        default:
          return Container();
      }
    } else {
      return Container();
    }
  }

  ErrorPacksWidget _getErrorPacksWidget() => ErrorPacksWidget(
        onPressed: () => _packsBloc
            .fetchPacksList()
            .then((value) => _packsBloc.fetchPacksList()),
      );

  Widget _getListWidget(List<PacksData> data) {
    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: 8),
      itemCount: data.length,
      itemBuilder: (context, i) {
        return InkWell(
          onTap: () => _navigate(data, i, context),
          child: PackListItemWidget(PackImageListItemData(
              title: data[i].title,
              subtitle: data[i].subtitle,
              cover: data[i].cover,
              backgroundImage: data[i].backgroundImageUrl,
              colorPrimary: parseColor(data[i].colorPrimary),
              coverSize: 72)),
        );
      },
    );
  }

  Future<void> _navigate(List<PacksData> data, int i, BuildContext context) {
    return checkConnectivity().then((connected) {
      if (connected) {
        return NavigationFactory.navigateToScreenFromString(
            data[i].type, data[i].id, context);
      } else {
        _packsBloc.fetchPacksList(true);
      }
    });
  }

  @override
  void dispose() {
    _packsBloc.dispose();
    super.dispose();
  }

  ///  This is for the skeleton screen
  Widget getLoadingWidget() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(height: 8),
          getBlankTile(MeditoColors.walterWhiteTrans),
          getBlankTile(MeditoColors.walterWhiteTrans),
          getBlankTile(MeditoColors.walterWhiteTrans),
          getBlankTile(MeditoColors.walterWhiteTrans),
          getBlankTile(MeditoColors.walterWhiteTrans),
          getBlankTile(MeditoColors.walterWhiteTrans),
          getBlankTile(MeditoColors.walterWhiteTrans),
          getBlankTile(MeditoColors.walterWhiteTrans),
          getBlankTile(MeditoColors.walterWhiteTrans),
          getBlankTile(MeditoColors.walterWhiteTrans),
          getBlankTile(MeditoColors.walterWhiteTrans),
          getBlankTile(MeditoColors.walterWhiteTrans),
          getBlankTile(MeditoColors.walterWhiteTrans),
        ],
      ),
    );
  }

  Widget getBlankTile(Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0, bottom: 16.0, left: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                color: color,
              ),
              height: 84,
            ),
          ),
        ],
      ),
    );
  }
}
