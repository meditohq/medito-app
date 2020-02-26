import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class ImageListItemWidget extends StatelessWidget {
  final String src;

  ImageListItemWidget({Key key, this.src}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(40.0),
        child: SvgPicture.network(
          src,
          placeholderBuilder: (BuildContext context) => Container(
              padding: const EdgeInsets.all(30.0),
              child: const CircularProgressIndicator()),
        ));
  }
}
