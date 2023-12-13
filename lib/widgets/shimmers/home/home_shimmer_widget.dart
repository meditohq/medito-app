import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

import '../widgets/box_shimmer_widget.dart';

class HomeShimmerWidget extends StatelessWidget {
  const HomeShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var chips = _chips();

    return SingleChildScrollView(
      child: SafeArea(
        child: Column(
          children: [
            _header(),
            _searchbar(),
            chips,
            chips,
            Column(
              children: List.generate(3, (index) => _shimmerList()),
            ),
          ],
        ),
      ),
    );
  }

  Padding _chips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: List.generate(
          5,
          (index) => Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: BoxShimmerWidget(
                height: 40,
                borderRadius: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Padding _searchbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: BoxShimmerWidget(
        height: 52,
        borderRadius: 12,
      ),
    );
  }

  Padding _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BoxShimmerWidget(
            height: 20,
            width: 40,
            borderRadius: 12,
          ),
          BoxShimmerWidget(
            height: 20,
            width: 80,
            borderRadius: 12,
          ),
        ],
      ),
    );
  }

  Padding _shimmerList() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: BoxShimmerWidget(
              height: 18,
              width: 150,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(
                  5,
                  (index) => _rowCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Padding _rowCard() {
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: Container(
        height: 154,
        width: 154,
        color: ColorConstants.greyIsTheNewGrey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              child: BoxShimmerWidget(
                height: 10,
                width: 300,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              child: BoxShimmerWidget(
                height: 10,
                width: 150,
              ),
            ),
            height8,
          ],
        ),
      ),
    );
  }
}
