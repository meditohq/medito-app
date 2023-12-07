import 'package:flutter/material.dart';
import '../widgets/box_shimmer_widget.dart';

class QuoteShimmerWidget extends StatelessWidget {
  const QuoteShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _chips(),
        ],
      ),
    );
  }

  Column _chips() {
    return Column(
      children: List.generate(
        4,
        (_) => BoxShimmerWidget(
          height: 40,
          borderRadius: 12,
        ),
      ),
    );
  }
}
