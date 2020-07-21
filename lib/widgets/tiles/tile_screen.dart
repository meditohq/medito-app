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

import 'package:Medito/widgets/text_file_widget.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../audioplayer/player_widget.dart';
import '../../tracking/tracking.dart';
import '../../utils/colors.dart';
import '../../utils/stats_utils.dart';
import '../../utils/utils.dart';
import '../../viewmodel/model/list_item.dart';
import '../../viewmodel/model/tile_item.dart';
import '../../viewmodel/tile_view_model.dart';
import '../bottom_sheet_widget.dart';
import '../column_builder.dart';
import '../folder_nav_widget.dart';
import '../streak_page.dart';
import '../streak_tiles_utils.dart';

class TileList extends StatefulWidget {
  TileList({Key key}) : super(key: key);

  @override
  TileListState createState() {
    return TileListState();
  }
}

class TileListState extends State<TileList> {
  final _viewModel = new TileListViewModelImpl();

  var listFuture;
  var streak = getCurrentStreak();

  SharedPreferences prefs;
  String streakValue = '0';

  @override
  void initState() {
    Tracking.trackEvent(Tracking.TILE, Tracking.SCREEN_LOADED, '');
    super.initState();
    listFuture = _viewModel.getTiles();

    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        this.prefs = prefs;
      });
    });
  }

  Future<void> _onPullToRefresh() async {
    setState(() {
      listFuture = _viewModel.getTiles(skipCache: true);
    });
  }

  Widget tileListWidget() {
    return RefreshIndicator(
      displacement: 80,
      color: MeditoColors.lightColor,
      backgroundColor: MeditoColors.darkColor,
      onRefresh: _onPullToRefresh,
      child: FutureBuilder(
        builder: (context, future) {
          if (future.connectionState == ConnectionState.none &&
                  future.hasData == null ||
              future.hasError) {
            return getErrorWidget();
          }

          if (future.connectionState == ConnectionState.waiting) {
            return getLoadingWidget();
          }

          return SingleChildScrollView(
            primary: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                children: <Widget>[
                  _getMeditoLogo(),
                  ListView.builder(
                    padding: EdgeInsets.only(left: 16, right: 16),
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: future.data != null ? future.data?.length : 0,
                    itemBuilder: (BuildContext context, int index) {
                      TileItem tile =
                          future.data != null ? future.data[index] : null;
                      if (tile != null &&
                          tile.tileType == TileType.announcement) {
                        return getHorizontalAnnouncementTile(tile);
                      } else if (tile != null &&
                          tile.tileType == TileType.large) {
                        return getHorizontalTile(tile);
                      } else {
                        return Container(
                          color: Colors.green,
                        );
                      }
                    },
                  ),
                  getTwoColumns(future.data)
                ],
              ),
            ),
          );
        },
        future: listFuture,
      ),
    );
  }

  Widget getErrorWidget() {
    return Column(
      children: <Widget>[
        _getMeditoLogo(),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                    child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: RaisedButton(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: new BorderRadius.circular(16.0),
                      ),
                      color: MeditoColors.darkColor,
                      onPressed: _onPullToRefresh,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Oops! There was an error.\n Tap to refresh',
                          style: Theme.of(context).textTheme.bodyText2,
                          textAlign: TextAlign.center,
                        ),
                      )),
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MeditoColors.darkBGColor,
      child: SafeArea(
        bottom: false,
        child: tileListWidget(),
      ),
    );
  }

  Widget getTwoColumns(List<TileItem> data) {
    data = data?.where((i) => i.tileType == TileType.small)?.toList();

    var secondColumnLength =
        (data == null ? 0 : data?.length) + 1; // + 1 for streak tile
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          //left column
          SizedBox(
            width: getColumWidth(),
            child: ColumnBuilder(
                itemCount: data == null ? 0 : data?.length,
                itemBuilder: (BuildContext context, int index) {
                  TileItem tile = data[index];
                  if (index < data.length / 2) {
                    return getTile(tile);
                  } else {
                    return Container();
                  }
                }),
          ),
          //right column
          SizedBox(
            width: getColumWidth(),
            child: ColumnBuilder(
                itemCount: secondColumnLength,
                itemBuilder: (BuildContext context, int index) {
                  if (index == secondColumnLength - 1) {
                    return StreakTileWidget(streak, 'Current Streak',
                        optionalText: UnitType.day, onClick: _onStreakTap);
                  }

                  TileItem tile = data[index];
                  if (data != null && index >= data.length / 2) {
                    return getTile(tile);
                  } else {
                    return Container();
                  }
                }),
          ),
        ],
      ),
    );
  }

  //todo horrible hack, but necessary because autosizetext cannot be passed unbound constraints
  //see here https://stackoverflow.com/questions/53882591/autoresize-text-to-fit-in-container-vertically
  double getColumWidth() => MediaQuery.of(context).size.width / 2 - 8;

  Widget getTile(TileItem item) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          color: parseColor(item.colorBackground),
        ),
        child: wrapWithInkWell(
            parseColor(item.colorBackground),
            item,
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: getColumWidth() - 48, //todo horrible hack
                    child: AutoSizeText(item.title,
                        maxLines: 2,
                        wrapWords: false,
                        style: Theme.of(context)
                            .textTheme
                            .headline6
                            .copyWith(color: parseColor(item.colorText))),
                  ),
                  Container(height: 16),
                  getNetworkImageWidget(item.thumbnail),
                ],
              ),
            )),
      ),
    );
  }

  Widget wrapWithInkWell(
    Color color,
    TileItem item,
    Widget w,
  ) {
    return Material(
        color: Colors.white.withOpacity(0.0),
        child: InkWell(
          splashColor: MeditoColors.lightColor,
          onTap: () => item != null ? _onTap(item) : null,
          borderRadius: BorderRadius.circular(16.0),
          child: w,
        ));
  }

  Widget getHorizontalAnnouncementTile(TileItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          color: MeditoColors.darkColor,
        ),
        child: wrapWithInkWell(
            parseColor(item.colorBackground),
            item,
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.description == null ? "" : item.description,
                      style: Theme.of(context).textTheme.caption,
                    ),
                  ),
                ],
              ),
            )),
      ),
    );
  }

  Widget getHorizontalTile(TileItem item) {
    return Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            color: item.colorBackground != null
                ? parseColor(item.colorBackground)
                : Colors.black,
          ),
          child: wrapWithInkWell(
            parseColor(item.colorBackground),
            item,
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Stack(
                children: <Widget>[
                  Positioned(
                      top: 0,
                      right: 0,
                      child: SizedBox(
                          height: 115,
                          child: getNetworkImageWidget(item.thumbnail,
                              startHeight: 140.0))),
                  //todo why is there space around this button?
                  Positioned(bottom: -4, child: getFlatButton(item)),
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      getTitleText(item),
                      getDescText(item),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  Widget getDescText(TileItem item) {
    return FractionallySizedBox(
      widthFactor: .6,
      child: Padding(
        padding: EdgeInsets.only(bottom: 62),
        child: Text(item.description,
            style: Theme.of(context)
                .textTheme
                .subtitle1
                .copyWith(color: parseColor(item.colorText))),
      ),
    );
  }

  Widget getTitleText(TileItem item) {
    return FractionallySizedBox(
      widthFactor: 0.6,
      child: Text(item.title,
          style: Theme.of(context)
              .textTheme
              .headline6
              .copyWith(color: parseColor(item.colorText))),
    );
  }

  Widget getFlatButton(TileItem item) {
    if (item.buttonLabel != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: FlatButton(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
          onPressed: () {
            _onTap(item);
          },
          color: parseColor(item.colorButton),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Text(item.buttonLabel.toUpperCase(),
              style: Theme.of(context).textTheme.headline3.copyWith(
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                  color: parseColor(item.colorButtonText))),
        ),
      );
    } else {
      return Container();
    }
  }

  _onTap(TileItem tile) {
    Tracking.trackEvent(
        Tracking.TILE, Tracking.TILE_TAPPED, tile.id + ' ' + tile.pathTemplate);

    if (tile.pathTemplate == 'audio') {
      _openBottomSheet(tile, _viewModel.getAudioData(id: tile.contentPath));
    } else if (tile.pathTemplate == 'default') {
      openNavWidget(tile);
    } else if (tile.pathTemplate == 'text') {
      openNavWidget(tile, textFuture: _viewModel.getTextFile(tile.contentPath));
    } else if (tile.pathTemplate == 'audio-set-daily') {
      _openBottomSheet(tile,
          _viewModel.getAudioFromSet(id: tile.contentPath, timely: 'daily'));
    } else if (tile.pathTemplate == 'audio-set-hourly') {
      _openBottomSheet(tile,
          _viewModel.getAudioFromSet(id: tile.contentPath, timely: 'hourly'));
    }
  }

  void _openBottomSheet(TileItem tile, Future data) {
    Tracking.trackEvent(Tracking.TILE, Tracking.BOTTOM_SHEET, tile.id);

    _viewModel.currentTile = tile;

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BottomSheetWidget(
            title: tile.title,
            onBeginPressed: _showPlayer,
            data: data,
          ),
        )).then((value) {
      setState(() {
        streak = getCurrentStreak();
      });
    });
  }

  _showPlayer(dynamic fileTapped, dynamic coverArt, dynamic coverColor,
      String title, String description, String contentText, String textColor, String bgMusicUrl) {
    var listItem = ListItem(_viewModel.currentTile.title,
        _viewModel.currentTile.id, ListItemType.file,
        description: _viewModel.currentTile.description,
        fileType: FileType.audio,
        contentText: contentText,
        url: _viewModel.currentTile.url,
        thumbnail: _viewModel.currentTile.thumbnail);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerWidget(
            fileModel: fileTapped,
            description: description,
            coverArt: coverArt,
            coverColor: coverColor,
            title: title,
            bgMusicUrl: bgMusicUrl,
            textColor: textColor,
            listItem: listItem,
            attributions: _viewModel.getAttributions(fileTapped.attributions)),
      ),
    ).then((value) {
      setState(() {
        streak = getCurrentStreak();
      });
    });
  }

  void openNavWidget(TileItem tile, {Future textFuture}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: '/nav'),
        builder: (c) {
          if (textFuture != null) {
            return TextFileWidget(
                firstTitle: tile.title,
                firstId: tile.contentPath,
                textFuture: textFuture);
          } else {
            return FolderNavWidget(
                firstTitle: tile.title, firstId: tile.contentPath);
          }
        },
      ),
    ).then((value) {
      setState(() {
        streak = getCurrentStreak();
      });
    });
  }

  _onStreakTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StreakWidget()),
    ).then((value) {
      setState(() {
        streak = getCurrentStreak();
      });
    });
  }

  Widget _getMeditoLogo() {
    return GestureDetector(
      onDoubleTap: () => _onPullToRefresh(),
      child: Padding(
        padding: const EdgeInsets.all(19.0),
        child: SvgPicture.asset(
          'assets/images/icon_ic_logo.svg',
        ),
      ),
    );
  }

  Widget getLoadingWidget() {
    TileItem item = TileItem("", "", "000000");
    return Column(
      children: [
        _getMeditoLogo(),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16),
          child: getHorizontalAnnouncementTile(item),
        ),
        Container(height: 8),
        getBlankTile(item, MeditoColors.lightColorLine),
        getBlankTile(item, MeditoColors.darkColor),
        getBlankTile(item, MeditoColors.lightColorLine),
        getBlankTile(item, MeditoColors.darkColor),
      ],
    );
  }

  Widget getBlankTile(TileItem item, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0, bottom: 16.0, left: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
              child: wrapWithInkWell(
            MeditoColors.lightColor,
            item,
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                color: color,
              ),
              height: 100,
            ),
          )),
        ],
      ),
    );
  }
}
