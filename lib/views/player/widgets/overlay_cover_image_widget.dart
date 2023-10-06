import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class OverlayCoverImageWidget extends StatelessWidget {
  const OverlayCoverImageWidget({super.key, required this.imageUrl});
  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    const totalPadding = 32;
    const horizontalPadding = totalPadding / 2;
    const verticalPadding = totalPadding / 2;
    var size = MediaQuery.of(context).size;

    return Container(
      height: size.width - totalPadding,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: NetworkImageWidget(
        url: imageUrl,
        isCache: true,
        width: size.width,
      ),
    );
  }
}
