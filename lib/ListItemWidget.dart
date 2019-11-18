import 'package:flutter/material.dart';

import 'ListItemModel.dart';

class ListItemWidget extends StatelessWidget {
  ListItemWidget({Key key, this.listItemModel}) : super(key: key);

  final FolderModel listItemModel;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.start, children: [
      Flexible(
        child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
            margin: EdgeInsets.all(4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(right: 8.0, left: 8),
                  child: Icon(Icons.folder),
                ),
                Flexible(
                    child: Container(
                        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      listItemModel.title,
                      style: const TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(height: 5),
                    getDescWidget(),
                  ],
                ))),
              ],
            )),
      )
    ]);
  }

  Widget getDescWidget() {
    if (listItemModel.description.isNotEmpty) {
      return Text(
        listItemModel.description,
        style: const TextStyle(
          fontSize: 16.0,
          color: Colors.black54,
        ),
      );
    } else
      return Container();
  }
}
