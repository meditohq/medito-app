import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class BoxShimmerComponent extends StatelessWidget {
  const BoxShimmerComponent({
    super.key,
    this.width,
    this.height,
    this.delayInMiliSeconds = 1500,
    this.child,
    this.borderRadius = 0,
  });
  final double? width, height;
  final int delayInMiliSeconds;
  final Widget? child;
  final double borderRadius;
  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return SizedBox(
      width: width ?? size.width,
      height: height ?? size.height,
      child: Shimmer.fromColors(
        baseColor: ColorConstants.greyIsTheNewBlack,
        highlightColor: ColorConstants.greyIsTheNewGrey.withOpacity(0.4),
        period: Duration(milliseconds: delayInMiliSeconds),
        child: Container(
          decoration: BoxDecoration(
            color: ColorConstants.almostBlack,
            borderRadius: BorderRadius.all(
              Radius.circular(borderRadius),
            ),
          ),
          width: width ?? size.width,
          height: height ?? size.height,
          child: child,
        ),
      ),
    );
  }
}
