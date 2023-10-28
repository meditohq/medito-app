import 'package:Medito/widgets/shimmers/widgets/box_shimmer_widget.dart';
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class SearchInitialPageShimmerWidget extends StatelessWidget {
  const SearchInitialPageShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 20, left: 15, right: 15),
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
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 16),
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
                  height: 15,
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
