import 'package:flutter/material.dart';
import 'viewmodel/list_item.dart';

import 'colors.dart';

class ListItemFolderWidget extends StatelessWidget {
  ListItemFolderWidget({Key key, this.listItemModel}) : super(key: key);

  final ListItem listItemModel;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.start, children: [
      Flexible(
        child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(right: 12.0, left: 4, top: 4),
                  child: Icon(Icons.folder, color: MeditoColors.lightColor),
                ),
                Flexible(
                    child: Container(
                        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(listItemModel.title,
                        style: Theme.of(context).textTheme.title),
                    Container(
                        height: listItemModel.description.isNotEmpty ? 5 : 0),
                    getDescWidget(context),
                  ],
                ))),
              ],
            )),
      )
    ]);
  }

  Widget getDescWidget(BuildContext context) {
    if (listItemModel.description != null &&
        listItemModel.description.isNotEmpty) {
      return Text(
        listItemModel.description,
        style: Theme.of(context).textTheme.subhead,
      );
    } else
      return Container();
  }
}
