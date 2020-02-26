import 'package:Medito/widgets/loading_list_widget.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../audioplayer/audio_singleton.dart';
import '../audioplayer/player_widget.dart';
import '../tracking/tracking.dart';
import '../utils/colors.dart';
import '../viewmodel/list_item.dart';
import '../viewmodel/main_view_model.dart';
import 'list_item_file_widget.dart';
import 'list_item_folder_widget.dart';
import 'list_item_image_widget.dart';
import 'nav_widget.dart';

Future<void> main() async {
  runApp(HomeScreenWidget());
  Tracking.initialiseTracker();
}

/// This Widget is the main application widget.
class HomeScreenWidget extends StatelessWidget {
  static const String _title = 'Medito';

  @override
  Widget build(BuildContext context) {
    Tracking.trackScreen(Tracking.HOME, Tracking.SCREEN_LOADED);

    return MaterialApp(
      theme: ThemeData(
          accentColor: MeditoColors.lightColor,
          textTheme:
              GoogleFonts.dMSansTextTheme(Theme.of(context).textTheme.copyWith(
                    title: TextStyle(
                        fontSize: 22.0,
                        color: MeditoColors.lightColor,
                        fontWeight: FontWeight.w600),
                    subhead: TextStyle(
                        fontSize: 16.0,
                        height: 1.3,
                        color: MeditoColors.lightTextColor,
                        fontWeight: FontWeight.normal),
                    display1: TextStyle(
                        //pill big
                        fontSize: 18.0,
                        color: MeditoColors.darkBGColor,
                        fontWeight: FontWeight.normal),
                    display2: TextStyle(
                        //pill small
                        fontSize: 14.0,
                        color: MeditoColors.lightColor,
                        fontWeight: FontWeight.normal),
                    display3: TextStyle(
                        //this is for bottom sheet text
                        fontSize: 16.0,
                        color: MeditoColors.lightColor,
                        fontWeight: FontWeight.normal),
                  ))),
      title: _title,
      home: Scaffold(
          appBar: null, //AppBar(title: const Text(_title)),
          body: Stack(
            children: <Widget>[
              MainWidget(),
            ],
          )),
    );
  }
}

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
//  _PlaceHolderState createState() => _PlaceHolderState();
  _MainWidgetState createState() => _MainWidgetState();
}

/////
class _MainWidgetState extends State<MainWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _viewModel = new SubscriptionViewModelImpl();
  Future<List<ListItem>> listFuture;

  String readMoreText = "";
  double textFileOpacity = 0;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.inactive:
        MeditoAudioPlayer().audioPlayer.pause();
        break;
      case AppLifecycleState.paused:
        MeditoAudioPlayer().audioPlayer.pause();
        break;
      case AppLifecycleState.detached:
        MeditoAudioPlayer().audioPlayer.pause();
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    listFuture = _viewModel.getPage();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
    ));

    MeditoAudioPlayer()
        .audioPlayer
        .onPlayerStateChanged
        .listen((AudioPlayerState s) {
      setState(() {
        _viewModel.currentState = s;
      });
    });

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: MeditoColors.darkBGColor,
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              IgnorePointer(
                ignoring: _viewModel.readMoreTextShowing,
                child: Column(
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
                    _viewModel.currentlySelectedFile != null
                        ? buildBottomSheet()
                        : Container()
                  ],
                ),
              ),
              getReadMoreView()
            ],
          ),
        ),
      ),
    );
  }

  Widget getReadMoreView() {
    return IgnorePointer(
      ignoring: !_viewModel.readMoreTextShowing,
      child: AnimatedOpacity(
        opacity: _viewModel.readMoreTextShowing ? 1 : 0,
        duration: Duration(milliseconds: 250),
        child: Container(
          color: MeditoColors.darkBGColor,
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: <Widget>[
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: DecoratedBox(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: getReadMoreTextWidget()),
                        ],
                      ),
                      decoration: BoxDecoration(
                        color: MeditoColors.darkColor,
                        borderRadius: BorderRadius.all(Radius.circular(16.0)),
                      ),
                    ),
                  )),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FlatButton(
                          child: Text("CLOSE"),
                          color: MeditoColors.lightColor,
                          onPressed: _closeReadMoreModal,
                        ),
                      ),
                    ],
                  )
                ],
              )),
        ),
      ),
    );
  }

  Widget getReadMoreTextWidget() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Text(readMoreText, style: Theme.of(context).textTheme.subhead),
      ),
    );
  }

  Widget getListView() {
    return FutureBuilder(
        future: listFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.hasData == false ||
              snapshot.hasData == null) {
            return LoadingListWidget();
          }

          if (snapshot.connectionState == ConnectionState.none) {
            return Text(
              "No connection. Please try again later",
              style: Theme.of(context).textTheme.display2,
            );
          }

          return new ListView.builder(
              itemCount: 1 + (snapshot.data == null ? 0 : snapshot.data.length),
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
        });
  }

  void folderTap(ListItem i) {
    Tracking.trackScreen(
        Tracking.FOLDER_TAPPED, Tracking.FOLDER_OPENED + " " + i.id);
    //if you tapped on a folder
    setState(() {
      _viewModel.addToNavList(i);
      listFuture = _viewModel.getPage(id: i.id);
    });
  }

  void fileTap(ListItem i) {
    if (i.fileType == FileType.audio) {
      _viewModel.playerOpen = true;
      Tracking.trackScreen(
          Tracking.FILE_TAPPED, Tracking.AUDIO_OPENED + " " + i.id);
      _showPlayer(i);
    } else if (i.fileType == FileType.both) {
      Tracking.trackScreen(
          Tracking.FILE_TAPPED, Tracking.AUDIO_OPENED + " " + i.id);
      _viewModel.playerOpen = true;
      _showPlayer(i);
    } else if (i.fileType == FileType.text) {
      Tracking.trackScreen(
          Tracking.FILE_TAPPED, Tracking.TEXT_ONLY_OPENED + " " + i.id);
      setState(() {
        _viewModel.addToNavList(i);
        textFileOpacity = 1;
      });
    }
  }

  void _showReadMoreModal(ListItem i) {
    setState(() {
      readMoreText = i.contentText;
      _viewModel.readMoreTextShowing = true;
    });
  }

  void _closeReadMoreModal() {
    _viewModel.readMoreTextShowing = false;
    setState(() {});
  }

  void _showPlayer(ListItem fileTapped) {
    if (fileTapped.id == _viewModel.currentlySelectedFile?.id) {
      return;
    }

    setState(() {
      MeditoAudioPlayer().audioPlayer.stop();
      _viewModel.currentlySelectedFile = fileTapped;
    });
  }

  Widget getFolderListItem(ListItem listItemModel) {
    return new ListItemFolderWidget(listItemModel: listItemModel);
  }

  Widget getFileListItem(ListItem item) {
    if (_viewModel.currentlySelectedFile?.id == item?.id) {
      return new ListItemFileWidget(
        item: item,
        currentlyPlayingState: _viewModel.currentState,
      );
    } else {
      return new ListItemFileWidget(
        item: item,
      );
    }
  }

  Widget getChildForListView(ListItem item) {
    if (item.type == ListItemType.folder) {
      return InkWell(
          onTap: () => folderTap(item),
          splashColor: MeditoColors.darkColor,
          child: getFolderListItem(item));
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
      if (_viewModel.readMoreTextShowing) {
        readMoreText = "";
        _viewModel.readMoreTextShowing = false;
      } else if (textFileOpacity == 1) {
        textFileOpacity = 0;
      } else {
        listFuture = _viewModel.getPage(id: id);
      }
      _viewModel.navList.removeLast();
    });
  }

  Widget buildBottomSheet() {
    var showReadMore =
        _viewModel.currentlySelectedFile?.contentText?.isNotEmpty;
    return PlayerWidget(
        fileModel: _viewModel.currentlySelectedFile,
        readMorePressed: _readMorePressed,
        showReadMoreButton: showReadMore == null ? false : showReadMore);
  }

  void _readMorePressed() {
    Tracking.trackScreen(
        Tracking.READ_MORE_TAPPED, _viewModel.currentlySelectedFile?.id);

    _showReadMoreModal(_viewModel.currentlySelectedFile);
  }

  Future<bool> _onWillPop() {
    if (_viewModel.readMoreTextShowing) {
      _viewModel.readMoreTextShowing = false;
      _closeReadMoreModal();
    } else if (_viewModel.navList.length > 1) {
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
                        child: Text(
                          content == null ? '' : content,
                          style: Theme.of(context).textTheme.subhead,
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
