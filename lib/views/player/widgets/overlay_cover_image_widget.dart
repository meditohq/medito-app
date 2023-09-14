import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class OverlayCoverImageWidget extends StatelessWidget {
  const OverlayCoverImageWidget({super.key, required this.imageUrl});
  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Container(
      height: size.width,
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: NetworkImageWidget(
        url: imageUrl,
        isCache: false,
        width: size.width,
      ),
    );
  }
}
