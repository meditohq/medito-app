import 'package:flutter/material.dart';
import '../widgets/box_shimmer_widget.dart';

class HeaderAndAnnouncementShimmerWidget extends StatelessWidget {
  const HeaderAndAnnouncementShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _header(),
          _chips(),
        ],
      ),
    );
  }

  GridView _chips() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8.0,
      mainAxisSpacing: 8.0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
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

  Padding _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BoxShimmerWidget(
            height: 40,
            width: 150,
            borderRadius: 12,
          ),
          BoxShimmerWidget(
            height: 35,
            width: 15,
            borderRadius: 12,
          ),
        ],
      ),
    );
  }
}
