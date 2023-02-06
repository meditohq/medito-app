import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class BoxShimmerComponent extends StatelessWidget {
  const BoxShimmerComponent(
      {super.key,
      this.width,
      this.height,
      this.delayInMiliSeconds = 1500,
      this.child});
  final double? width, height;
  final int delayInMiliSeconds;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? MediaQuery.of(context).size.width,
      height: height ?? MediaQuery.of(context).size.height,
      child: Shimmer.fromColors(
        baseColor: MeditoColors.greyIsTheNewGrey,
        highlightColor: MeditoColors.greyIsTheNewGrey.withOpacity(0.4),
        period: Duration(milliseconds: delayInMiliSeconds),
        child: Container(
          color: MeditoColors.almostBlack,
          width: width ?? MediaQuery.of(context).size.width,
          height: height ?? MediaQuery.of(context).size.height,
          child: child,
        ),
      ),
    );
  }
}
