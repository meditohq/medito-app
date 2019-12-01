import 'package:flutter/material.dart';

class NavWidget extends StatefulWidget {
  const NavWidget({Key key, this.list, this.backPressed}) : super(key: key);

  final List<String> list;
  final ValueChanged<String> backPressed;

  @override
  _NavWidgetState createState() => new _NavWidgetState();
}

class _NavWidgetState extends State<NavWidget>
    with SingleTickerProviderStateMixin {
  var _color1 = Colors.red;
  var _color2 = Colors.green;
  BorderRadiusGeometry _borderRadiusSmall = BorderRadius.circular(13);
  BorderRadiusGeometry _borderRadiusLarge = BorderRadius.circular(16);
  var _paddingSmall = 8.0;
  var _paddingLarge = 12.0;

  var _item1CurrentColor;
  var _item1Padding;
  BorderRadiusGeometry _item1Radius;
  var _item2CurrentColor;
  var _item2Padding;
  BorderRadiusGeometry _item2Radius;

  @override
  void initState() {
    super.initState();

    _item1CurrentColor = _color1;
    _item1Radius = _borderRadiusLarge;
    _item1Padding = _paddingLarge;

    _item2CurrentColor = _color1;
    _item2Radius = _borderRadiusLarge;
    _item2Padding = _paddingLarge;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: getPills(),
      ),
    );
  }

  List<Widget> getPills() {
    List<Widget> columns = new List<Widget>();

    for (int i = 0; i < widget.list.length; i++) {
      setState(() {
        if (i == 0) {
          _item1CurrentColor = _color2;
          _item1Radius = _borderRadiusSmall;
          _item1Padding = _paddingSmall;
        } else {
          _item1CurrentColor = _color1;
          _item1Radius = _borderRadiusLarge;
          _item1Padding = _paddingLarge;
        }
      });

      var label = widget.list[i];
      if (i == 0) {
        label = "< " + label;
      }

      columns.add(GestureDetector(
        onTap: () {
          if (i == 0) widget.backPressed(widget.list[i]);
        },
        child: AnimatedContainer(
          padding: EdgeInsets.all(i == 0 ? _item1Padding : _item2Padding),
          decoration: BoxDecoration(
            color: i == 0 ? _item1CurrentColor : _item2CurrentColor,
            borderRadius: i == 0 ? _item1Radius : _item2Radius,
          ),
          duration: Duration(seconds: 1),
          child: Text(label, style: TextStyle(color: Colors.white)),
        ),
      ));
    }
    return columns;
  }
}
