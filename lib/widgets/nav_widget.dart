import 'package:Medito/utils/colors.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/widgets/pill_utils.dart';
import 'package:flutter/material.dart';

import '../viewmodel/list_item.dart';

class NavWidget extends StatefulWidget {
  const NavWidget({Key key, this.list, this.backPressed}) : super(key: key);

  final List<ListItem> list;
  final ValueChanged<String> backPressed;

  @override
  _NavWidgetState createState() => new _NavWidgetState();
}

class _NavWidgetState extends State<NavWidget>
    with SingleTickerProviderStateMixin {

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: getPills(),
      ),
    );
  }

  List<Widget> getPills() {
    List<Widget> columns = new List<Widget>();
    if (widget.list == null) return columns;

    int startNumber = 0;
    if (widget.list.length >= 2) {
      startNumber = widget.list.length - 2;
    }
    for (int i = startNumber; i < widget.list.length; i++) {
      var label = widget.list[i].title;
      if (widget.list.length > 1 && i == startNumber) {
        label = "< " + label;
      }

      columns.add(GestureDetector(
          onTap: () {
            Tracking.trackEvent(Tracking.BREADCRUMB,
                Tracking.BREADCRUMB_TAPPED, widget.list.last?.id);

            if (i == startNumber && widget.list.length > 1)
              widget.backPressed(widget.list[i].id);
          },
          child: AnimatedContainer(
            margin: EdgeInsets.only(top: i == startNumber ? 0 : 8),
            padding: getEdgeInsets(i, startNumber),
            decoration: getBoxDecoration(i, startNumber),
            duration: Duration(days: 1),
            child: getTextLabel(label, i, startNumber, context),
          )));
    }

    return columns;
  }

}
