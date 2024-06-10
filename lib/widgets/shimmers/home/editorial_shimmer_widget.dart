import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

import '../widgets/box_shimmer_widget.dart';

class EditorialShimmerWidget extends StatelessWidget {
  const EditorialShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: padding20),
      child: BoxShimmerWidget(
        height: 200,
        width: size.width,
        borderRadius: 14,
      ),
    );
  }
}
