import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

import 'widgets/box_shimmer_widget.dart';

class TrackShimmerWidget extends StatelessWidget {
  const TrackShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var shimmerList = _shimmerList();

    var list = List.generate(3, (index) => shimmerList);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BoxShimmerWidget(
            height: 380,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                height8,
                height8,
                BoxShimmerWidget(
                  height: 15,
                  width: 150,
                  borderRadius: 14,
                ),
                height8,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: list,
                ),
                height8,
                height8,
                BoxShimmerWidget(
                  height: 15,
                  width: 150,
                  borderRadius: 14,
                ),
                height8,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: list,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Padding _shimmerList() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: 171,
        height: 56,
        decoration: BoxDecoration(
          color: ColorConstants.greyIsTheNewGrey,
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
        ),
        child: Center(
          child: BoxShimmerWidget(
            height: 10,
            width: 100,
            borderRadius: 14,
          ),
        ),
      ),
    );
  }
}
