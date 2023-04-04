import 'package:Medito/components/components.dart';
import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class BackgroundImageComponent extends StatelessWidget {
  const BackgroundImageComponent({super.key, required this.imageUrl});
  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    
    return Stack(
      children: [
        SizedBox(
          height: size.height,
          child: NetworkImageComponent(
            url: imageUrl,
            isCache: true,
          ),
        ),
        Container(
          height: size.height,
          color: ColorConstants.almostBlack.withOpacity(0.85),
        ),
      ],
    );
  }
}
