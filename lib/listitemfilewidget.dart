import 'package:flutter/material.dart';
import 'package:medito/viewmodel/filemodel.dart';

class ListItemFileWidget extends StatelessWidget {
  ListItemFileWidget({Key key, this.item}) : super(key: key);

  final FileModel item;

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
                  child: getIcon(),
                ),
                Flexible(
                    child: Container(
                        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.fileName,
                      style: const TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ))),
              ],
            )),
      )
    ]);
  }

  Icon getIcon() {
    switch (item.type) {
      case FileType.audio:
        return Icon(Icons.description);
        break;
      case FileType.text:
        return Icon(Icons.audiotrack);
        break;
    }
    return  Icon(Icons.audiotrack);
  }
}
