import 'package:Medito/utils/colors.dart';
import 'package:flutter/material.dart';

class LoadingItemWidget extends StatefulWidget {
  LoadingItemWidget({Key key, this.index}) : super(key: key);

  final int index;

  @override
  _LoadingItemWidgetState createState() => _LoadingItemWidgetState();
}

class _LoadingItemWidgetState extends State<LoadingItemWidget>
    with SingleTickerProviderStateMixin {
  Animation<double> animation;
  AnimationController controller;

  @override
  void initState() {
    super.initState();
    var dur = getDuration();
    controller =
        AnimationController(duration: Duration(milliseconds: dur), vsync: this);
    animation = Tween<double>(begin: 0, end: 1).animate(controller)
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      });
    controller.repeat(reverse: true);
  }

  int getDuration() => (250 - (10 * widget.index));

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: animation.value,
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
                      child: Container(
                        decoration: buildBoxDecoration(MeditoColors.lightColorLine),
                        height: 24,
                        width: 24,
                      )),
                  Flexible(
                      child: Container(
                          child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                          decoration:
                              buildBoxDecoration(MeditoColors.lightColorLine),
                          child: Text("                      ",
                              style: Theme.of(context).textTheme.title)),
                      Container(height: 5),
                      Container(
                          decoration:
                              buildBoxDecoration(MeditoColors.lightColorTrans),
                          child: Text(
                              "                                            ",
                              style: Theme.of(context).textTheme.title)),
                    ],
                  ))),
                ],
              )),
        )
      ]),
      duration: Duration(seconds: 1),
    );
  }

  BoxDecoration buildBoxDecoration(Color color) {
    return new BoxDecoration(
        color: color,
        borderRadius: new BorderRadius.all(
          const Radius.circular(30.0),
        ));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
