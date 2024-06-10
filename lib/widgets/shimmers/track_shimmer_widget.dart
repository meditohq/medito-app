import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

import 'widgets/box_shimmer_widget.dart';

class TrackShimmerWidget extends StatelessWidget {
  const TrackShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BoxShimmerWidget(
            height: 280,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                height12,
                BoxShimmerWidget(
                  height: 15,
                  width: 150,
                  borderRadius: 14,
                ),
                height12,
                BoxShimmerWidget(
                  height: 15,
                  width: 200,
                  borderRadius: 14,
                ),
                height32,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: BoxShimmerWidget(
                        height: 48,
                        width: size.width,
                        borderRadius: 14,
                      ),
                    ),
                    width12,
                    Expanded(
                      child: BoxShimmerWidget(
                        height: 48,
                        width: size.width,
                        borderRadius: 14,
                      ),
                    ),
                  ],
                ),
                height32,
                BoxShimmerWidget(
                  height: 48,
                  width: size.width,
                  borderRadius: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
