/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

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
    try{controller.repeat(reverse: true);}
    catch(e){
      print('animation repeat error');
    }
  }

  int getDuration() => (250 - (10 * widget.index));

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: animation.value,
      duration: Duration(seconds: 1),
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
                        decoration: buildBoxDecoration(MeditoColors.walterWhiteLine),
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
                              buildBoxDecoration(MeditoColors.walterWhiteLine),
                          child: Text('                      ',
                              style: Theme.of(context).textTheme.headline6)),
                      Container(height: 5),
                      Container(
                          decoration:
                              buildBoxDecoration(MeditoColors.walterWhiteTrans),
                          child: Text(
                              '                                            ',
                              style: Theme.of(context).textTheme.headline6)),
                    ],
                  ))),
                ],
              )),
        )
      ]),
    );
  }

  BoxDecoration buildBoxDecoration(Color color) {
    return BoxDecoration(
        color: color,
        borderRadius: BorderRadius.all(
          const Radius.circular(30.0),
        ));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
