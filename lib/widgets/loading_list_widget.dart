import 'package:Medito/utils/colors.dart';
import 'package:Medito/viewmodel/list_item.dart';
import 'package:Medito/widgets/nav_widget.dart';
import 'package:flutter/material.dart';

class LoadingListWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        itemCount: 6,
        itemBuilder: (context, i) {
          if (i == 0) {
            var list = [
              ListItem("               ", "                ", null,
                  parentId: "...")
            ];
            return IgnorePointer(ignoring: true, child: NavWidget(list: list));
          }
          return loadingItem(context, i);
        });
  }

  Widget loadingItem(BuildContext context, int i) {
    i = i + 1;
    return Opacity(
      opacity: 1 - i / 7,
      child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
        Flexible(
          child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(right: 12.0, left: 4, top: 4),
                    child: Container(                          decoration: getBoxDecoration(),
                    height: 18, width: 18,)
                  ),
                  Flexible(
                      child: Container(
                          child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                          decoration: getBoxDecoration(),
                          child: Text("                      ",
                              style: Theme.of(context).textTheme.title)),
                      Container(height: 5),
                      Container(
                          decoration: getBoxDecoration(),
                          child: Text(
                              "                                            ",
                              style: Theme.of(context).textTheme.title)),
                    ],
                  ))),
                ],
              )),
        )
      ]),
    );
  }

  BoxDecoration getBoxDecoration() {
    return new BoxDecoration(
                          gradient: new LinearGradient(
                            colors: [MeditoColors.lightColorLine, MeditoColors.lightColorTrans],
                          ),
                        );
  }
}
