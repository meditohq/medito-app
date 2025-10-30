import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class BoxShimmerWidget extends StatelessWidget {
  const BoxShimmerWidget({
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
        baseColor: Theme.of(context).colorScheme.surface,
        highlightColor: Theme.of(context).colorScheme.surface.withAlpha(((0.4).clamp(0.0, 1.0) * 255).round()),
        period: Duration(milliseconds: delayInMiliSeconds),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
