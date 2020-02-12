import 'package:flutter/material.dart';

class ImageListItemWidget extends StatelessWidget {
  final String src;

  ImageListItemWidget({Key key, this.src}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Image.network(src);
  }
}
