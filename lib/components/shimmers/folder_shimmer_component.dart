import 'package:Medito/components/shimmers/components/box_shimmer_component.dart';
import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:flutter/material.dart';

class FolderShimmerComponent extends StatelessWidget {
  const FolderShimmerComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SingleChildScrollView(
      child: Column(
        children: [
          BoxShimmerComponent(
            height: 380,
          ),
          height8,
          for (int i = 0; i < 6; i++) _shimmerList(size)
        ],
      ),
    );
  }

  Padding _shimmerList(Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        height: 100,
        width: size.width,
        color: MeditoColors.greyIsTheNewBlack,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: BoxShimmerComponent(
                height: 10,
                width: 300,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: BoxShimmerComponent(
                height: 10,
                width: 200,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
