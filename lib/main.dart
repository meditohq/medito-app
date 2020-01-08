import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medito/api/api.dart';
import 'package:medito/listitemfilewidget.dart';
import 'package:medito/listitemfolderwidget.dart';
import 'package:medito/navwidget.dart';
import 'package:medito/viewmodel/ListItemModel.dart';
import 'package:medito/viewmodel/filemodel.dart';
import 'package:medito/viewmodel/listviewmodel.dart';

void main() => runApp(MyApp());

/// This Widget is the main application widget.
class MyApp extends StatelessWidget {
  static const String _title = 'Medito';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
          textTheme: GoogleFonts.dMSansTextTheme(
        Theme.of(context).textTheme,
      )),
      title: _title,
      home: Scaffold(
        appBar: null, //AppBar(title: const Text(_title)),
        body: MainWidget(),
      ),
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
class _MainWidgetState extends State<MainWidget> {
  final _viewModel = new SubscriptionViewModelImpl();
  final controller = TextEditingController();
  int currentPage = 0;
  static List<FolderModel> currentFolderList = [];
  static List<FileModel> currentFilesList = [];

  @override
  Widget build(BuildContext context) {
    // set up first page
    if (currentFolderList.isEmpty) {
      currentFolderList.addAll(_viewModel.getFirstFolderContents());
    }
    // end of set up first page

    return SafeArea(
      child: Column(
        children: <Widget>[
          SizedBox(
            //todo: height is magic number. main list should show below nav widget, preferably animate as the size of nav midget changes
            height: 120,
            child: Center(
              child: new NavWidget(
                  list: _viewModel.list, backPressed: _backPressed),
            ),
          ),
          getListView(),
        ],
      ),
    );
  }

  void _backPressed(String value) {
    setState(() {
      currentFolderList = _viewModel.backUp();
      currentFilesList.clear();
      var files = _viewModel.getFilesForId(currentFolderList[0].parentId);
      currentFilesList.addAll(files);
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
          return InkWell(
              splashColor: Colors.orange,
              child: getChildForListView(i),
              onTap: () {
                listItemTap(i);
                setState(() {});
              });
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
      showPlayer(getFileTapped(i));
    }
  }

  FileModel getFileTapped(int i) =>
      currentFilesList[i - currentFolderList.length];

  Widget getFileListItem(FileModel file) {
    return new ListItemFileWidget(item: file);
  }

  void showPlayer(FileModel fileTapped) {

  }
}
