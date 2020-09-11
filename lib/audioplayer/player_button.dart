import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class PlayerButton extends StatelessWidget {
  final IconData icon;
  final Future<void> Function() onPressed;
  final Color bgColor;
  final String text;
  final Color textColor;
  final SvgPicture image;

  PlayerButton(
      {Key key,
      this.icon,
      this.onPressed,
      this.bgColor,
      this.text,
      this.textColor,
      this.image})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ButtonTheme(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
      height: 56.0,
      child: FlatButton(
          color: bgColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              image != null
                  ? image
                  : Icon(
                      icon,
                      size: 24,
                      color: text ==
                              null //usually if there is no text it'll just be a play/pause button
                          ? Colors.white
                          : textColor,
                    ),
              text == null
                  ? Container()
                  : Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        text,
                        style: Theme.of(context).textTheme.subtitle1.copyWith(
                            color: textColor, fontWeight: FontWeight.w500),
                      ),
                    )
            ],
          ),
          onPressed: onPressed),
    );
  }
}
