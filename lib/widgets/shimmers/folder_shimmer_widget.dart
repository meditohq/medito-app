import 'package:Medito/constants/constants.dart';
import 'package:Medito/widgets/shimmers/widgets/box_shimmer_widget.dart';
import 'package:flutter/material.dart';

class FolderShimmerWidget extends StatelessWidget {
  const FolderShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SingleChildScrollView(
      child: Column(
        children: [
          BoxShimmerWidget(
            height: 380,
          ),
          height8,
          Column(
            children: List.generate(5, (index) => _shimmerList(size)),
          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: BoxShimmerWidget(
                height: 10,
                width: 300,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: BoxShimmerWidget(
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
