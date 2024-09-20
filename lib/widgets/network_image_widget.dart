import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:medito/constants/constants.dart';
import 'package:shimmer/shimmer.dart';

class NetworkImageWidget extends ConsumerWidget {
  final String url;
  final double? height, width;
  final bool shouldCache;
  final Gradient? gradient;
  final Widget? errorWidget;

  const NetworkImageWidget({
    Key? key,
    required this.url,
    this.height,
    this.width,
    this.shouldCache = false,
    this.gradient,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url.contains('.svg')) {
      return SvgPicture.network(
        url,
        fit: BoxFit.contain,
        height: height,
        width: width,
      );
    } else {
      if (shouldCache) {
        return CachedNetworkImage(
          imageUrl: url,
          imageBuilder: (context, imageProvider) => Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ),
            foregroundDecoration: BoxDecoration(
              gradient: gradient,
            ),
          ),
          placeholder: (context, url) => _shimmerLoading(),
          errorWidget: (context, url, error) {
            if (errorWidget != null) {
              return errorWidget!;
            }

            return _shimmerLoading();
          },
        );
      }

      return Image.network(
        url,
        fit: BoxFit.cover,
        height: height,
        width: width,
        cacheHeight: height?.round(),
        cacheWidth: width?.round(),
        loadingBuilder: (context, child, loadingProgress) {
          return loadingProgress == null ? child : _shimmerLoading();
        },
        errorBuilder: (context, error, stackTrace) {
          if (errorWidget != null) {
            return errorWidget!;
          }

          return Image.asset(
            AssetConstants.dalle,
            fit: BoxFit.cover,
          );
        },
      );
    }
  }

  Shimmer _shimmerLoading() {
    return Shimmer.fromColors(
      period: const Duration(seconds: 1),
      baseColor: ColorConstants.black,
      highlightColor: ColorConstants.greyIsTheNewBlack,
      child: Container(
        color: ColorConstants.black,
        height: height,
        width: width,
      ),
    );
  }
}
