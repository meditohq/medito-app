import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:flutter/material.dart';

import '../widgets/box_shimmer_widget.dart';

class TilesShimmerWidget extends StatelessWidget {
  const TilesShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: padding20),
      child: Row(
        children: [
          _tiles(context),
          width16,
          _tiles(context),
        ],
      ),
    );
  }

  Expanded _tiles(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Expanded(
      child: BoxShimmerWidget(
        height: 100,
        width: size.width,
        borderRadius: 12,
      ),
    );
  }
}
