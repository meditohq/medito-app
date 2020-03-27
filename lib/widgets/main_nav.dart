import 'package:Medito/audioplayer/player_widget.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/viewmodel/list_item.dart';
import 'package:Medito/viewmodel/main_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'bottom_sheet_widget.dart';
import 'list_item_file_widget.dart';
import 'list_item_image_widget.dart';
import 'loading_list_widget.dart';
import 'nav_widget.dart';

class MainStateless extends StatelessWidget {
  MainStateless({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MainWidget();
  }
}

class MainWidget extends StatefulWidget {
  MainWidget({Key key}) : super(key: key);

  @override
  _MainWidgetState createState() => _MainWidgetState();
}

class _MainWidgetState extends State<MainWidget> with TickerProviderStateMixin {
  final _viewModel = new SubscriptionViewModelImpl();
  Future<List<ListItem>> listFuture;

  String readMoreText = "";
  double textFileOpacity = 0;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    listFuture = _viewModel.getPageChildren();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
    ));

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: MeditoColors.darkBGColor,
        body: SafeArea(
          maintainBottomViewPadding: false,
          child: Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                      child: Stack(
                    children: <Widget>[
                      getListView(),
                      AnimatedOpacity(
                          duration: Duration(milliseconds: 0),
                          opacity: textFileOpacity,
                          child: getInnerTextView()),
                    ],
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget getReadMoreTextWidget() {
    var title = _viewModel.currentlySelectedFile == null
        ? ''
        : _viewModel.currentlySelectedFile.title;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.title),
            Container(height: 8.0),
            Text(readMoreText, style: Theme.of(context).textTheme.subhead),
          ],
        ),
      ),
    );
  }

  Widget getListView() {
    return RefreshIndicator(
      color: MeditoColors.darkBGColor,
      backgroundColor: MeditoColors.darkColor,
      child: FutureBuilder(
          future: listFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.none) {
              return Text(
                "No connection. Please try again later",
                style: Theme.of(context).textTheme.display2,
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.hasData == false ||
                snapshot.hasData == null) {
              return LoadingListWidget();
            }

            return new ListView.builder(
                itemCount:
                    1 + (snapshot.data == null ? 0 : snapshot.data.length),
                shrinkWrap: true,
                itemBuilder: (BuildContext context, int i) {
                  if (i == 0) {
                    return NavWidget(
                      list: _viewModel.navList,
                      backPressed: _backPressed,
                    );
                  }
                  return Column(
                    children: <Widget>[
                      getChildForListView(snapshot.data[i - 1]),
                    ],
                  );
                });
          }),
      onRefresh: _onPullToRefresh,
    );
  }

  Future<void> _onPullToRefresh() async {
    setState(() {
      listFuture = _viewModel.getPageChildren(
          id: _viewModel.getCurrentPageId(), skipCache: true);
    });
  }

  void folderTap(ListItem i) {
    Tracking.trackScreen(
        Tracking.FOLDER_TAPPED, Tracking.FOLDER_OPENED + " " + i.id);
    //if you tapped on a folder
    setState(() {
      _viewModel.addToNavList(i);
      listFuture = _viewModel.getPageChildren(id: i.id);
    });
  }

  void fileTap(ListItem item) {
    if (item.fileType == FileType.audioset) {
      Tracking.trackScreen(
          Tracking.FILE_TAPPED, Tracking.AUDIO_OPENED + " " + item.id);
      _showPlayerBottomSheet(item);
    } else if (item.fileType == FileType.audio) {
      Tracking.trackScreen(
          Tracking.FILE_TAPPED, Tracking.AUDIO_OPENED + " " + item.id);
      _showPlayerBottomSheet(item);
    } else if (item.fileType == FileType.both) {
      Tracking.trackScreen(
          Tracking.FILE_TAPPED, Tracking.AUDIO_OPENED + " " + item.id);
      _showPlayerBottomSheet(item);
    } else if (item.fileType == FileType.text) {
      Tracking.trackScreen(
          Tracking.FILE_TAPPED, Tracking.TEXT_ONLY_OPENED + " " + item.id);
      setState(() {
        _viewModel.addToNavList(item);
        textFileOpacity = 1;
      });
    }
  }

  _showPlayerBottomSheet(ListItem listItem) {
    _viewModel.currentlySelectedFile = listItem;

    showModalBottomSheet(
      context: context,
      clipBehavior: Clip.hardEdge,
      elevation: 2.0,
      builder: (context) => BottomSheetWidget(
        title: listItem.title,
        onBeginPressed: _showPlayer,
        data: listItem.fileType == FileType.audioset
            ? _viewModel.getAudioFromSet(
                id: listItem.id, timely: listItem.title.toLowerCase())
            : _viewModel.getAudioData(id: listItem.id),
      ),
    );
  }

  _showPlayer(
      dynamic fileTapped, dynamic coverArt, dynamic coverColor, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PlayerWidget(
              fileModel: fileTapped,
              title: title,
              coverArt: coverArt,
              coverColor: coverColor,
              listItem: _viewModel.currentlySelectedFile,
              attributions:
                  _viewModel.getAttributions(fileTapped.attributions))),
    );
  }

  Widget getFileListItem(ListItem item) {
    return new ListItemWidget(
      item: item,
    );
  }

  Widget getChildForListView(ListItem item) {
    if (item.type == ListItemType.folder) {
      return InkWell(
          onTap: () => folderTap(item),
          splashColor: MeditoColors.darkColor,
          child: getFileListItem(item));
    } else if (item.type == ListItemType.file) {
      return InkWell(
          onTap: () => fileTap(item),
          splashColor: MeditoColors.darkColor,
          child: getFileListItem(item));
    } else {
      return new ImageListItemWidget(src: item.url);
    }
  }

  void _backPressed(String id) {
    setState(() {
      if (textFileOpacity == 1) {
        textFileOpacity = 0;
      } else {
        listFuture = _viewModel.getPageChildren(id: id);
      }
      _viewModel.navList.removeLast();
    });
  }

  Future<bool> _onWillPop() {
    if (_viewModel.navList.length > 1) {
      _backPressed(_viewModel.navList.last.parentId);
      Tracking.trackScreen(
          Tracking.BACK_PRESSED,
          Tracking.CURRENTLY_SELECTED_FILE +
              "" +
              _viewModel.currentlySelectedFile?.id);
    } else {
      return new Future(() => true);
    }
    return new Future(() => false);
  }

  Widget getInnerTextView() {
    var content = _viewModel?.navList?.last?.contentText;

    return IgnorePointer(
      ignoring: textFileOpacity == 0,
      child: Container(
        color: MeditoColors.darkBGColor,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            NavWidget(
              list: _viewModel?.navList,
              backPressed: _backPressed,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        child: MarkdownBody(
                          selectable: true,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(Theme.of(context))
                                  .copyWith(
                                      p: Theme.of(context).textTheme.subhead),
                          data: content == null ? '' : content,
                          imageDirectory: 'https://raw.githubusercontent.com',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
