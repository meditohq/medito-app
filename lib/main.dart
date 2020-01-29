import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medito/api/api.dart';
import 'package:medito/audioplayer/playerwidget.dart';
import 'package:medito/listitemfilewidget.dart';
import 'package:medito/listitemfolderwidget.dart';
import 'package:medito/navwidget.dart';
import 'package:medito/viewmodel/ListItemModel.dart';
import 'package:medito/viewmodel/filemodel.dart';
import 'package:medito/viewmodel/listviewmodel.dart';

import 'audioplayer/audiosingleton.dart';

void main() => runApp(MyApp());

/// This Widget is the main application widget.
class MyApp extends StatelessWidget {
  static const String _title = 'Medito';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
          textTheme: GoogleFonts.dMSansTextTheme(
            Theme
                .of(context)
                .textTheme,
          )),
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

class _PlaceHolderState extends State<MainWidget> {
  final _viewModel = new SubscriptionViewModelImpl();
  final controller = TextEditingController();
  int currentPage = 0;
  static List<FolderModel> filesList = [];

  final emailAddressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final String emailRegex =
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$";

  @override
  Widget build(BuildContext context) {
    // Build a Form widget using the _formKey created above.
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Image.network("https://source.unsplash.com/AvLHH8qYbAI",
                height: 300, width: double.infinity, fit: BoxFit.fitWidth),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                  "To make sure we provide the best service possible, we give access to new comers on a daily basis. \n\nEnter your email below and we will let you know when you can access the app.",
                  style: const TextStyle(
                      color: const Color(0xff656565),
                      fontStyle: FontStyle.normal,
                      fontSize: 16.0)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: TextFormField(
                decoration: InputDecoration(
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 1.0),
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    hintText: 'email address'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (!RegExp(emailRegex).hasMatch(value)) {
                    return "Please enter a valid email address";
                  }
                  if (value.isEmpty) {
                    return 'Please enter your emaill address';
                  }
                  return null;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
              child: Text("* We’ll never share your email address",
                  style: const TextStyle(
                      fontStyle: FontStyle.normal, fontSize: 10.0)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FlatButton(
                textColor: Colors.white,
                color: Colors.black,
                onPressed: () {
                  // Validate returns true if the form is valid, or false
                  // otherwise.
                  if (_formKey.currentState.validate()) {
                    // If the form is valid, display a Snackbar.
                    _fire();
                    Scaffold.of(context).showSnackBar(
                        SnackBar(content: Text('Subscribing...')));
                  }
                },
                child: Text(
                  'JOIN WAITING LIST',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _fire() {
    Api.updateSubscribers(emailAddressController.text)
        .whenComplete(_doneSnackBar);
  }

  FutureOr _doneSnackBar() {
    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text('Complete. Thanks!'),
      backgroundColor: Colors.green,
    ));
  }
}

/////
class _MainWidgetState extends State<MainWidget> with TickerProviderStateMixin {
  final _viewModel = new SubscriptionViewModelImpl();
  final controller = TextEditingController();
  int currentPage = 0;
  static List<FolderModel> currentFolderList = [];
  static List<FileModel> currentFilesList = [];
  var bottomSheetController;

  AnimationController _controller;
  Animation _animation;

  double screenHeight;
  double screenWidth;
  double bottomSheetViewHeight = 119;
  double transcriptionOpacity = 0;
  double fileListOpacity = 1;
  String transcriptionText = "";

  void initAnimation() {
    screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    screenHeight = MediaQuery
        .of(context)
        .size
        .height;

    _controller = new AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

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
    MeditoAudioPlayer()
        .audioPlayer
        .onPlayerStateChanged
        .listen((AudioPlayerState s) {
      if (s == AudioPlayerState.COMPLETED) {
        hidePlayer();
      }
    });

    // set up first page
    if (currentFolderList.isEmpty) {
      initAnimation();
      currentFolderList.addAll(_viewModel.getFirstFolderContents());
    }
    // end of set up first page

    return Scaffold(
      body: Stack(children: <Widget>[
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              new NavWidget(
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

  Container buildBottomSheet() {
    return new Container(
      color: Colors.green,
      child: new PlayerWidget(
        fileModel: _viewModel.currentlySelectedFile,
      ),
      margin: EdgeInsets.only(top: _animation.value),
      height: bottomSheetViewHeight,
      width: screenWidth,
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

  void _backPressed(String value) {
    setState(() {
      if (transcriptionOpacity == 1) {
        transcriptionText = "";
        transcriptionOpacity = 0;
        fileListOpacity = 1;
        _viewModel.navList.removeLast();
      } else {
        currentFolderList = _viewModel.backUp();
        currentFilesList.clear();
        var files = _viewModel.getFilesForId(currentFolderList[0].parentId);
        currentFilesList.addAll(files);
      }
    });
  }

  Widget getFolderListItem(FolderModel listItemModel) {
    return new ListItemFolderWidget(listItemModel: listItemModel);
  }

  Widget getListView() {
    var length = currentFolderList.length + currentFilesList.length;

    return new ListView.builder(
        itemCount: length,
        shrinkWrap: true,
        itemBuilder: (BuildContext context, int i) {
          return Column(
            children: <Widget>[
              InkWell(
                  splashColor: Colors.orange,
                  child: getChildForListView(i),
                  onTap: () {
                    listItemTap(i);
                    setState(() {});
                  }),
              Container(height: i == length -1 ? 200: 0)
            ],
          );
        });
  }

  Widget getChildForListView(int i) {
    if (i < currentFolderList.length) {
      return getFolderListItem(currentFolderList[i]);
    } else {
      return getFileListItem(getFileTapped(i));
    }
  }

  void listItemTap(int i) {
    //if you tapped on a folder
    if (i < currentFolderList.length) {
      _viewModel.addToNavList(currentFolderList[i].title);

      int id = currentFolderList[i].id;
      var folder = _viewModel.getFolderContents(id);
      var files = _viewModel.getFilesForId(id);

      currentFilesList.clear();
      currentFilesList.addAll(files);

      if (folder.length != 0) {
        currentFolderList.clear();
        currentFolderList.addAll(folder);
      }
    }
    //if you tapped on a file
    else {
      var fileTapped = getFileTapped(i);
      showPlayer(fileTapped);

      if (fileTapped.transcription.isNotEmpty) {
        _viewModel.addToNavList(fileTapped.fileName);
        setState(() {
          transcriptionText = fileTapped.transcription;
          transcriptionOpacity = 1;
          fileListOpacity = 0;
        });
      }
    }
  }

  FileModel getFileTapped(int i) =>
      currentFilesList[i - currentFolderList.length];

  Widget getFileListItem(FileModel file) {
    return new ListItemFileWidget(item: file);
  }

  void showPlayer(FileModel fileTapped) {
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
}
