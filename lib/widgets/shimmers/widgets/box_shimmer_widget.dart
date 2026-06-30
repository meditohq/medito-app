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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF3A3A44)
        : const Color(0xFFE0E0E0);
    final highlightColor = isDark
        ? const Color(0xFF4E4E5A)
        : const Color(0xFFF5F5F5);

    return SizedBox(
      width: width ?? size.width,
      height: height ?? size.height,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: Duration(milliseconds: delayInMiliSeconds),
        child: Container(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
          ),
          width: width ?? size.width,
          height: height ?? size.height,
          child: child,
        ),
      ),
    );
  }
}
