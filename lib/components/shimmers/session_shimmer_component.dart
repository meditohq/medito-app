import 'package:Medito/components/shimmers/components/box_shimmer_component.dart';
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class SessionShimmerComponent extends StatelessWidget {
  const SessionShimmerComponent({super.key});

  @override
  Widget build(BuildContext context) {
    var shimmerList = _shimmerList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BoxShimmerComponent(
            height: 380,
          ),
          height8,
          height8,
          BoxShimmerComponent(
            height: 15,
            width: 150,
            borderRadius: 14,
          ),
          height8,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              for (int i = 0; i < 3; i++) shimmerList,
            ],
          ),
          height8,
          height8,
          BoxShimmerComponent(
            height: 15,
            width: 150,
            borderRadius: 14,
          ),
          height8,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [for (int i = 0; i < 5; i++) shimmerList],
          ),
        ],
      ),
    );
  }

  Padding _shimmerList() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: 171,
        height: 56,
        decoration: BoxDecoration(
          color: ColorConstants.greyIsTheNewGrey,
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
        ),
        child: Center(
          child: BoxShimmerComponent(
            height: 10,
            width: 100,
            borderRadius: 14,
          ),
        ),
      ),
    );
  }
}
