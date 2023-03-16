import 'package:Medito/components/components.dart';
import 'package:Medito/constants/colors/color_constants.dart';
import 'package:flutter/material.dart';

class BackgroundImageComponent extends StatelessWidget {
  const BackgroundImageComponent({super.key, required this.imageUrl});
  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: ImageFiltered(
        imageFilter: ColorFilter.mode(
            ColorConstants.almostBlack.withOpacity(0.4), BlendMode.colorBurn),
        child: NetworkImageComponent(url: imageUrl),
      ),
    );
  }
}
