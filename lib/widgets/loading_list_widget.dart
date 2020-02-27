import 'package:Medito/viewmodel/list_item.dart';
import 'package:Medito/widgets/loading_item_widget.dart';
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
              ListItem("            ", "             ", null, parentId: "...")
            ];
            return IgnorePointer(ignoring: true, child: NavWidget(list: list));
          }
          return LoadingItemWidget(index: i + 1);
        });
  }

}
