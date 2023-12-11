import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class OverlayCoverImageWidget extends StatelessWidget {
  const OverlayCoverImageWidget({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size.width;

    print(size);

    double dimension;

    dimension = size <= 380 ? size - 128 : size - 64;

    return SizedBox(
      width: dimension,
      height: dimension,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: NetworkImageWidget(
          url: imageUrl,
          isCache: true,
        ),
      ),
    );
  }
}
