import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class OverlayCoverImageWidget extends StatelessWidget {
  const OverlayCoverImageWidget({super.key, required this.imageUrl});
  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    const divisor = 2.1;
    final coverImageHeight = MediaQuery.of(context).size.height / divisor;

    return Container(
      height: coverImageHeight,
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: NetworkImageWidget(
        url: imageUrl,
        isCache: true,
        height: 342,
        width: 342,
      ),
    );
  }
}
