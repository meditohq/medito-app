import 'package:Medito/components/components.dart';
import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class BackgroundImageComponent extends StatelessWidget {
  const BackgroundImageComponent({super.key, required this.imageUrl});
  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height,
          child: NetworkImageComponent(
            url: imageUrl,
            isCache: false,
          ),
        ),
        Container(
          height: MediaQuery.of(context).size.height,
          color: ColorConstants.almostBlack.withOpacity(0.85),
        ),
      ],
    );
  }
}
