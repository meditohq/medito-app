import 'package:flutter/material.dart';

class NavWidget extends StatefulWidget {
  const NavWidget({Key key, this.list, this.navigationListKey}) : super(key: key);

  final GlobalKey<AnimatedListState> navigationListKey;
  final List<String> list;
  @override
  _NavWidgetState createState() => new _NavWidgetState();
}

class _NavWidgetState extends State<NavWidget> {
  var begin = Offset(-1.0, 0.0);
  var end = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: AnimatedList(
        padding: const EdgeInsets.all(12),
        key: widget.navigationListKey,
        shrinkWrap: true,
        itemBuilder: (content, index, animation) {
          var tween = Tween(begin: begin, end: end);
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: Container(child: Text(widget.list[index])),
          );
        },
        initialItemCount: widget.list.length,
      ),
    );
  }
}
