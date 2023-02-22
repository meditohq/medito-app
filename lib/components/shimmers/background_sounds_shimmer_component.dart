import 'package:Medito/components/shimmers/components/box_shimmer_component.dart';
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class BackgroundSoundsShimmerComponent extends StatelessWidget {
  const BackgroundSoundsShimmerComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SingleChildScrollView(
      child: Column(
        children: [
          BoxShimmerComponent(
            height: 130,
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
        color: ColorConstants.greyIsTheNewGrey,
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
