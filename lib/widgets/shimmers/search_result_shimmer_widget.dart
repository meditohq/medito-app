import 'package:Medito/widgets/shimmers/widgets/box_shimmer_widget.dart';
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class SearchResultShimmerWidget extends StatelessWidget {
  const SearchResultShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 20, left: 15, right: 15),
      child: Column(
        children: List.generate(5, (index) => _shimmerList()),
      ),
    );
  }

  Padding _shimmerList() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          BoxShimmerWidget(
            height: 56,
            width: 56,
          ),
          width8,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BoxShimmerWidget(
                height: 10,
                width: 150,
              ),
              height8,
              BoxShimmerWidget(
                height: 10,
                width: 250,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
