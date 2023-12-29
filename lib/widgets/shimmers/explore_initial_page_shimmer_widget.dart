import 'package:Medito/constants/constants.dart';
import 'package:Medito/widgets/shimmers/widgets/box_shimmer_widget.dart';
import 'package:flutter/material.dart';

class ExploreInitialPageShimmerWidget extends StatelessWidget {
  const ExploreInitialPageShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: 20,
        left: padding16,
        right: padding16,
      ),
      child: Column(
        children: List.generate(8, (index) => _shimmerList()),
      ),
    );
  }

  Container _shimmerList() {
    return Container(
      decoration: BoxDecoration(
        color: ColorConstants.onyx,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: EdgeInsets.all(padding16),
      margin: EdgeInsets.only(bottom: padding16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                height8,
                BoxShimmerWidget(
                  height: 16,
                  width: 150,
                ),
                height8,
                BoxShimmerWidget(
                  height: 10,
                  width: 260,
                ),
                height4,
                BoxShimmerWidget(
                  height: 10,
                  width: 200,
                ),
              ],
            ),
          ),
          width12,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: BoxShimmerWidget(
              height: 80,
              width: 80,
            ),
          ),
        ],
      ),
    );
  }
}
