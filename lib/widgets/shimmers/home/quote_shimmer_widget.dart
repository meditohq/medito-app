import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:flutter/material.dart';

import '../widgets/box_shimmer_widget.dart';

class QuoteShimmerWidget extends StatelessWidget {
  const QuoteShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Column(
      children: [
        _lines(size.width * 0.9),
        height8,
        _lines(size.width * 0.7),
        height8,
        _lines(size.width * 0.5),
      ],
    );
  }

  BoxShimmerWidget _lines(double width) {
    return BoxShimmerWidget(
      height: 16,
      width: width,
      borderRadius: 12,
    );
  }
}
