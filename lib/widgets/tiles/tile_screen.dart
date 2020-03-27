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
          child: Column(
            children: <Widget>[
              ListView.builder(
                padding: EdgeInsets.only(left: 16, right: 16),
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: projectSnap.data?.length,
                itemBuilder: (BuildContext context, int index) {
                  TileItem tile = projectSnap.data[index];
                  if (tile.tileType == TileType.large) {
                    return getHorizontalTile(tile);
                  } else {
                    return Container();
                  }
                },
              ),
              twoColumnsTile(projectSnap.data)
            ],
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
            Image.network(
              'https://img.icons8.com/ios/72/blood-sample.png',
              height: 54,
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
    data = data.where((i) => i.tileType == TileType.small).toList();

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
                itemCount: data.length,
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
                itemCount: data.length,
                itemBuilder: (BuildContext context, int index) {
                  TileItem tile = data[index];
                  if (index >= data.length / 2) {
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
      child: GestureDetector(
        onTap: () => _onTap(item),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            color: parseColor(item.colorBackground),
          ),
          child: Padding(
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
                    height: 134, child: SvgPicture.network(item.thumbnail)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget getHorizontalTile(TileItem tile) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: GestureDetector(
        onTap: () => _onTap(tile),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            color: tile.colorBackground != null
                ? parseColor(tile.colorBackground)
                : Colors.black,
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
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
                      Text(tile.title,
                          style: Theme.of(context)
                              .textTheme
                              .title
                              .copyWith(color: parseColor(tile.colorText))),
                      Text(tile.description,
                          style: Theme.of(context)
                              .textTheme
                              .subhead
                              .copyWith(color: parseColor(tile.colorText))),
                      tile.buttonLabel != null
                          ? FlatButton(
                              color: parseColor(tile.colorButton),
                              child: Text(tile.buttonLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .subhead
                                      .copyWith(
                                          color: parseColor(
                                              tile.colorButtonText))),
                            )
                          : Container()
                    ],
                  ),
                ),
                Container(height: 16),
                Expanded(
                    child: SizedBox(
                        height: 130,
                        child: SvgPicture.network(tile.thumbnail))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _onTap(TileItem tile) {
    if (tile.pathType == '/') {
      _openBottomSheet(tile);
    }
  }

  void _openBottomSheet(TileItem tile) {
    _viewModel.currentTile = tile;
    showModalBottomSheet(
      context: context,
      clipBehavior: Clip.hardEdge,
      elevation: 2.0,
      builder: (context) => BottomSheetWidget(
        title: tile.title,
        onBeginPressed: _showPlayer,
        data: _viewModel.getAudioData(id: tile.contentPath),
      ),
    );
  }

  _showPlayer(dynamic fileTapped, dynamic coverArt, dynamic coverColor, String title) {
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
              coverArt: coverArt,
              coverColor: coverColor,
              title: title,
              listItem: listItem,
              attributions:
                  _viewModel.getAttributions(fileTapped.attributions))),
    );
  }
}
