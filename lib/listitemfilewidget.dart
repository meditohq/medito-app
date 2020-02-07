import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:medito/viewmodel/list_item.dart';

class ListItemFileWidget extends StatelessWidget {
  ListItemFileWidget({Key key, this.item}) : super(key: key);

  final ListItem item;

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
                  child: getIcon(),
                ),
                Flexible(
                    child: Container(
                        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(item.title, style: Theme.of(context).textTheme.title),
                    item.description == null || item.description.isEmpty
                        ? Container()
                        : Text(
                            item.description,
                            style: Theme.of(context).textTheme.subhead,
                          ),
                  ],
                ))),
              ],
            )),
      )
    ]);
  }

  Widget getIcon() {
    var path;
    switch (item.fileType) {
      case FileType.audio:
        return Icon(Icons.audiotrack);
        break;
      case FileType.text:
        path = 'assets/images/ic_document.svg';
        break;
      case FileType.both:
        path = 'assets/images/ic_audio.svg';
        break;
    }
    return SvgPicture.asset(
      path,
    );
  }
}
