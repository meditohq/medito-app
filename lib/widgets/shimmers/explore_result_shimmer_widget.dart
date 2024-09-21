import 'package:medito/constants/constants.dart';
import 'package:medito/widgets/shimmers/widgets/box_shimmer_widget.dart';
import 'package:flutter/material.dart';

class ExploreResultShimmerWidget extends StatelessWidget {
  const ExploreResultShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 20, left: 15, right: 15),
      itemCount: 8,
      itemBuilder: (context, index) => _shimmerList(),
    );
  }

  Widget _shimmerList() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
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
