import 'package:flutter/material.dart';
import 'package:medito_app/ListItemModel.dart';
import 'package:medito_app/ListItemWidget.dart';
import 'package:medito_app/navwidget.dart';
import 'package:medito_app/viewmodel/listviewmodel.dart';

void main() => runApp(MyApp());

/// This Widget is the main application widget.
class MyApp extends StatelessWidget {
  static const String _title = 'Medito';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      home: Scaffold(
        appBar: AppBar(title: const Text(_title)),
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
  _MainWidgetState createState() => _MainWidgetState();
}

class _MainWidgetState extends State<MainWidget> {
  final _viewModel = new SubscriptionViewModelImpl();
  final controller = TextEditingController();
  int currentPage = 0;
  static List<FolderModel> filesList = [];

  @override
  Widget build(BuildContext context) {
    // set up first page
    if (filesList.isEmpty) {
      filesList.addAll(_viewModel.getFirstFolderContents());
    }
    // end of set up first page

    return Column(
      children: <Widget>[
        SizedBox(
           //todo: height is magic number. main list should show below nav widget, preferably animate as the size of nav midget changes
          height: 120,
          child: Center(
            child: new NavWidget(
                list: _viewModel.list,
                backPressed: _backPressed),
          ),
        ),
        getListView(),
      ],
    );
  }

  void _backPressed(String value){

  }

  Widget getFolderListItem(FolderModel listItemModel) {
    return new ListItemWidget(listItemModel: listItemModel);
  }

  Widget getListView() {
    return new ListView.builder(
        itemCount: filesList.length,
        shrinkWrap: true,
        itemBuilder: (BuildContext context, int i) {
          return InkWell(
              splashColor: Colors.orange,
              child: getFolderListItem(filesList[i]),
              onTap: () {
                listItemTap(i);
                setState(() {});
              });
        });
  }

  void listItemTap(int i) {
    _viewModel.addToNavList(filesList[i].title);

    if (_viewModel.list.length > 2) {
      _viewModel.removeFromNavList(0);
    }

    int id = filesList[i].id;
    List<FolderModel> folder = _viewModel.getFolderContents(id);
    if (folder.length != 0) {
      filesList.clear();
      filesList.addAll(folder);
    }
  }

}
