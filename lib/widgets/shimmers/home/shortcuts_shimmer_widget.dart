import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:flutter/material.dart';

import '../widgets/box_shimmer_widget.dart';

class ShortcutsShimmerWidget extends StatelessWidget {
  const ShortcutsShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _shortcuts(),
    );
  }

  GridView _shortcuts() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8.0,
      mainAxisSpacing: 8.0,
      padding: const EdgeInsets.symmetric(horizontal: padding20),
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      childAspectRatio: 3,
      children: List.generate(4, (index) {
        return BoxShimmerWidget(
          height: 40,
          borderRadius: 12,
        );
      }),
    );
  }
}
