import 'package:Medito/audioplayer/player_widget.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/viewmodel/list_item.dart';
import 'package:Medito/viewmodel/tile_item.dart';
import 'package:Medito/viewmodel/tile_view_model.dart';
import 'package:Medito/widgets/bottom_sheet_widget.dart';
import 'package:Medito/widgets/column_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../main_nav.dart';

class TileList extends StatefulWidget {
  TileList({Key key}) : super(key: key);

  @override
  TileListState createState() {
    return TileListState();
  }
}

class TileListState extends State<TileList> {
  final _viewModel = new TileListViewModelImpl();

  @override
  void initState() {
    super.initState();
  }

  Widget tileListWidget() {
    return FutureBuilder(
      builder: (context, projectSnap) {
        if (projectSnap.connectionState == ConnectionState.none &&
            projectSnap.hasData == null) {
          //print('project snapshot data is: ${projectSnap.data}');
          return Container();
        }
        return SingleChildScrollView(
          primary: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              children: <Widget>[
                ListView.builder(
                  padding: EdgeInsets.only(left: 16, right: 16),
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount:
                      projectSnap.data != null ? projectSnap.data?.length : 0,
                  itemBuilder: (BuildContext context, int index) {
                    TileItem tile =
                        projectSnap.data != null ? projectSnap.data[index] : null;
                    if (tile != null && tile.tileType == TileType.announcement) {
                      return getHorizontalAnnouncementTile(tile);
                    } else if (tile != null && tile.tileType == TileType.large) {
                      return getHorizontalTile(tile);
                    } else {
                      return Container(
                        color: Colors.green,
                      );
                    }
                  },
                ),
                twoColumnsTile(projectSnap.data)
              ],
            ),
          ),
        );
      },
      future: _viewModel.getTiles(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MeditoColors.darkBGColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(19.0),
              child: SvgPicture.asset(
                'assets/images/icon_ic_logo.svg',
              ),
            ),
            Expanded(
              child: tileListWidget(),
            ),
          ],
        ),
      ),
    );
  }

  Widget twoColumnsTile(List<TileItem> data) {
    data = data?.where((i) => i.tileType == TileType.small)?.toList();

    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          //left column
          Expanded(
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
          Expanded(
            child: ColumnBuilder(
                itemCount: data == null ? 0 : data?.length,
                itemBuilder: (BuildContext context, int index) {
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

  Widget wrapWithRowExpanded(Widget w) {
    return Row(
      children: <Widget>[
        Expanded(child: w),
      ],
    );
  }

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
                  Text(item.title,
                      style: Theme.of(context)
                          .textTheme
                          .title
                          .copyWith(color: parseColor(item.colorText))),
                  Container(height: 16),
                  SizedBox(
                      height: 134,
                      child: Image.network(item.thumbnail, headers: null)),
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
          onTap: () => _onTap(item),
          borderRadius: BorderRadius.circular(16.0),
          child: w,
        ));
  }

  Widget getHorizontalAnnouncementTile(TileItem item) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
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
                      item.description,
                      style: Theme.of(context).textTheme.display4,
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
              padding:
                  const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(item.title,
                            style: Theme.of(context)
                                .textTheme
                                .title
                                .copyWith(color: parseColor(item.colorText))),
                        Text(item.description,
                            style: Theme.of(context)
                                .textTheme
                                .subhead
                                .copyWith(color: parseColor(item.colorText))),
                        item.buttonLabel != null
                            ? Padding(
                                padding:
                                    const EdgeInsets.only(top: 8.0, bottom: 8),
                                child: FlatButton(
                                  padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
                                  onPressed: () {},
                                  color: parseColor(item.colorButton),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(item.buttonLabel.toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .subhead
                                          .copyWith(
                                              color: parseColor(
                                                  item.colorButtonText))),
                                ),
                              )
                            : Container()
                      ],
                    ),
                  ),
                  Container(height: 16),
                  Expanded(
                      child: SizedBox(
                    height: 130,
                    child: Image.network(item.thumbnail),
                  )),
                ],
              ),
            ),
          ),
        ));
  }

  _onTap(TileItem tile) {
    if (tile.pathTemplate == 'audio') {
      _openBottomSheet(tile, _viewModel.getAudioData(id: tile.contentPath));
    } else if (tile.pathTemplate == 'default') {
      openNavWidget(tile);
    } else if (tile.pathTemplate == 'text') {
      openNavWidget(tile, textFuture: _viewModel.getTextFile(tile.contentPath));
    } else if (tile.pathTemplate == 'audio-set') {
      _openBottomSheet(tile, _viewModel.getAudioFromDailySet(
          id: tile.contentPath));
    }
  }

  void _openBottomSheet(TileItem tile, Future data) {
    _viewModel.currentTile = tile;
    showModalBottomSheet(
      context: context,
      clipBehavior: Clip.hardEdge,
      elevation: 2.0,
      builder: (context) => BottomSheetWidget(
        title: tile.title,
        onBeginPressed: _showPlayer,
        data: data,
      ),
    );
  }

  _showPlayer(dynamic fileTapped, dynamic coverArt, dynamic coverColor,
      String title, String description) {
    var listItem = ListItem(_viewModel.currentTile.title,
        _viewModel.currentTile.id, ListItemType.file,
        description: _viewModel.currentTile.description,
        fileType: FileType.audio,
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
              listItem: listItem,
              attributions:
                  _viewModel.getAttributions(fileTapped.attributions))),
    );
  }

  void openNavWidget(TileItem tile, {Future textFuture}) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => MainNavWidget(
                firstTitle: tile.title,
                firstId: tile.contentPath,
                textFuture: textFuture)));
  }
}
