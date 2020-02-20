import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'audioplayer/audio_singleton.dart';
import 'audioplayer/player_widget.dart';
import 'colors.dart';
import 'list_item_file_widget.dart';
import 'list_item_folder_widget.dart';
import 'list_item_image_widget.dart';
import 'nav_widget.dart';
import 'viewmodel/list_item.dart';
import 'viewmodel/main_view_model.dart';

void main() => runApp(MyApp());

/// This Widget is the main application widget.
class MyApp extends StatelessWidget {
  static const String _title = 'Medito';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
          accentColor: MeditoColors.lightColor,
          textTheme:
              GoogleFonts.dMSansTextTheme(Theme.of(context).textTheme.copyWith(
                    title: TextStyle(
                        fontSize: 24.0,
                        color: MeditoColors.lightColor,
                        fontWeight: FontWeight.w600),
                    subhead: TextStyle(
                        fontSize: 16.0,
                        color: Color(0xffa7aab1),
                        fontWeight: FontWeight.normal),
                    display1: TextStyle(
                        //pill big
                        fontSize: 18.0,
                        color: Color(0xff22282d),
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
  final controller = TextEditingController();
  int currentPage = 0;
  var bottomSheetController;

  double screenHeight;
  double screenWidth;
  double transcriptionOpacity = 0;
  double fileListOpacity = 1;
  String transcriptionText = "";

  var playerKey;

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
        backgroundColor: Color(0xff22282D),
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              fileListOpacity > 0
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AnimatedOpacity(
                          opacity: fileListOpacity,
                          duration: Duration(milliseconds: 250),
                          child: NavWidget(
                            list: _viewModel.navList,
                            backPressed: _backPressed,
                          ),
                        ),
                        Expanded(
                            child: AnimatedOpacity(
                                duration: Duration(milliseconds: 250),
                                opacity: fileListOpacity,
                                child: getListView())),
                        _viewModel.currentlySelectedFile != null
                            ? buildBottomSheet()
                            : Container()
                      ],
                    )
                  : Container(),
              getTranscriptionView()
            ],
          ),
        ),
      ),
    );
  }

  AnimatedOpacity getTranscriptionView() {
    return AnimatedOpacity(
      duration: Duration(milliseconds: 250),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: transcriptionOpacity > 0
            ? Column(
                children: <Widget>[
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: DecoratedBox(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: getText()),
                        ],
                      ),
                      decoration: BoxDecoration(
                        color: MeditoColors.lightGreyColor,
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
                          onPressed: _closeTranscriptionView,
                        ),
                      ),
                    ],
                  )
                ],
              )
            : Container(),
      ),
      opacity: transcriptionOpacity,
    );
  }

  Widget getText() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child:
            Text(transcriptionText, style: Theme.of(context).textTheme.subhead),
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
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.connectionState == ConnectionState.none) {
            return Text(
              "No connection. Please try again later",
              style: Theme.of(context).textTheme.display2,
            );
          }

          return new ListView.builder(
              itemCount: snapshot.data == null ? 0 : snapshot.data.length,
              shrinkWrap: true,
              itemBuilder: (BuildContext context, int i) {
                return Column(
                  children: <Widget>[
                    getChildForListView(snapshot.data[i]),
                  ],
                );
              });
        });
  }

  void listItemTap(ListItem i) {
    //if you tapped on a folder
    if (i.type == ListItemType.folder) {
      setState(() {
        _viewModel.addToNavList(i);
        listFuture = _viewModel.getPage(id: i.id);
      });
    }
    //if you tapped on a file
    else {
      if (i.fileType == FileType.audio || i.fileType == FileType.both) {
        _viewModel.playerOpen = true;
        showPlayer(i);
      } else if (i.fileType == FileType.text) {
        showTextModal(i);
      }
    }
  }

  void showTextModal(ListItem i) {
    setState(() {
      transcriptionText = i.contentText;
      transcriptionOpacity = 1;
      fileListOpacity = 0;
      _viewModel.playerOpen = false;
    });
  }

  void showPlayer(ListItem fileTapped) {
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
          onTap: () => listItemTap(item),
          splashColor: MeditoColors.darkGreyColor,
          child: getFolderListItem(item));
    } else if (item.type == ListItemType.file) {
      return InkWell(
          onTap: () => listItemTap(item),
          splashColor: MeditoColors.darkGreyColor,
          child: getFileListItem(item));
    } else {
      return new ImageListItemWidget(src: item.url);
    }
  }

  void _backPressed(String id) {
    setState(() {
      if (transcriptionOpacity == 1) {
        transcriptionText = "";
        transcriptionOpacity = 0;
        fileListOpacity = 1;
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
        key: playerKey,
        fileModel: _viewModel.currentlySelectedFile,
        readMorePressed: _readMorePressed,
        showReadMoreButton: showReadMore == null ? false : showReadMore);
  }

  void _readMorePressed() {
    showTextModal(_viewModel.currentlySelectedFile);
  }

  void _closeTranscriptionView() {
    _viewModel.playerOpen = true;
    fileListOpacity = 1;
    transcriptionOpacity = 0;
    setState(() {});
  }

  Future<bool> _onWillPop() {
    if (_viewModel.navList.length > 1) {
      _backPressed(_viewModel.navList.last.parentId);
    } else {
      return new Future(() => true);
    }
    return new Future(() => false);
  }
}
