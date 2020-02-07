import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medito/audioplayer/playerwidget.dart';
import 'package:medito/listitemfilewidget.dart';
import 'package:medito/listitemfolderwidget.dart';
import 'package:medito/viewmodel/list_item.dart';
import 'package:medito/viewmodel/listviewmodel.dart';

import 'audioplayer/audiosingleton.dart';
import 'navwidget.dart';

void main() => runApp(MyApp());

/// This Widget is the main application widget.
class MyApp extends StatelessWidget {
  static const String _title = 'Medito';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
          textTheme:
              GoogleFonts.dMSansTextTheme(Theme.of(context).textTheme.copyWith(
                    title: TextStyle(
                        fontSize: 24.0,
                        color: Color(0xff2e3134),
                        fontWeight: FontWeight.w600),
                    subhead: TextStyle(
                        fontSize: 16.0,
                        color: Color(0xff595959),
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
class _MainWidgetState extends State<MainWidget> with TickerProviderStateMixin {
  final _viewModel = new SubscriptionViewModelImpl();
  Future<List<ListItem>> listFuture;
  final controller = TextEditingController();
  int currentPage = 0;
  var bottomSheetController;

  AnimationController _controller;
  Animation _animation;

  double screenHeight;
  double screenWidth;
  double bottomSheetViewHeight = 119;
  double transcriptionOpacity = 0;
  double fileListOpacity = 1;
  String transcriptionText = "";

  @override
  void initState() {
    super.initState();
    listFuture = _viewModel.getPage();
  }

  void initAnimation() {
    // call after initState because MediaQuery
    // cannot complete until initState has completed
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    _controller = new AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    )..addStatusListener((i) {
        print(i);
      });

    _animation = Tween<double>(
            end: screenHeight - bottomSheetViewHeight, begin: screenHeight)
        .animate(_controller)
          ..addStatusListener((listener) {
            if (listener == AnimationStatus.completed) {
              _viewModel.playerOpen = true;
            } else if (listener == AnimationStatus.dismissed) {
              _viewModel.playerOpen = false;
            }
          });
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      initAnimation();
    }

    MeditoAudioPlayer()
        .audioPlayer
        .onPlayerStateChanged
        .listen((AudioPlayerState s) {
      if (s == AudioPlayerState.COMPLETED) {
        hidePlayer();
      }
    });

    return Scaffold(
      backgroundColor: Color(0xfffff1ec),
      body: Stack(children: <Widget>[
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              NavWidget(
                list: _viewModel.navList,
                backPressed: _backPressed,
              ),
              Expanded(child: buildFolderNavigator()),
            ],
          ),
        ),
        new AnimatedBuilder(
          builder: (context, child) {
            return buildBottomSheet();
          },
          animation: _animation,
        )
      ]),
    );
  }

  Stack buildFolderNavigator() {
    return Stack(
      children: <Widget>[
        Opacity(
          child: getListView(),
          opacity: fileListOpacity,
        ),
        Opacity(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(transcriptionText),
          ),
          opacity: transcriptionOpacity,
        )
      ],
    );
  }

  Widget getListView() {
    return FutureBuilder(
        future: listFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.none ||
              snapshot.hasData == false ||
              snapshot.hasData == null) {
            return Container(
              color: Colors.red,
            );
          }

          return new ListView.builder(
              itemCount: snapshot.data == null ? 0 : snapshot.data.length,
              shrinkWrap: true,
              itemBuilder: (BuildContext context, int i) {
                return Column(
                  children: <Widget>[
                    InkWell(
                        splashColor: Colors.orange,
                        child: getChildForListView(snapshot.data[i]),
                        onTap: () {
                          listItemTap(snapshot.data[i]);
                          setState(() {});
                        }),
                    Container(height: i == snapshot.data.length - 1 ? 200 : 0)
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
        showPlayer(i);
      }

      if (i.contentText.isNotEmpty) {
        _viewModel.addToNavList(i);
        setState(() {
          transcriptionText = i.contentText;
          transcriptionOpacity = 1;
          fileListOpacity = 0;
        });
      }
    }
  }

  void showPlayer(ListItem fileTapped) {
    if (fileTapped == _viewModel.currentlySelectedFile) {
      return;
    }

    setState(() {
      MeditoAudioPlayer().audioPlayer.stop();
      _viewModel.currentlySelectedFile = fileTapped;
    });

    if (!_viewModel.playerOpen) {
      _controller.forward();
    }
  }

  void hidePlayer() {
    setState(() {
      _viewModel.currentlySelectedFile = null;
    });
    if (_viewModel.playerOpen) {
      _controller.reverse();
      _viewModel.playerOpen = false;
    }
  }

  Widget getFolderListItem(ListItem listItemModel) {
    return new ListItemFolderWidget(listItemModel: listItemModel);
  }

  Widget getFileListItem(ListItem item) {
    return new ListItemFileWidget(item: item);
  }

  Widget getChildForListView(ListItem item) {
    if (item.type == ListItemType.folder) {
      return getFolderListItem(item);
    } else {
      return getFileListItem(item);
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
    return Container(
      child: new Container(
        color: Colors.green,
        child: new PlayerWidget(
          fileModel: _viewModel.currentlySelectedFile,
        ),
        margin: EdgeInsets.only(top: _animation.value),
        height: bottomSheetViewHeight,
      ),
    );
  }
}
