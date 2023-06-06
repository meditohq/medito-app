import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';

class NetworkImageWidget extends ConsumerWidget {
  final String url;
  final double? height, width;
  final bool isCache;
  const NetworkImageWidget({
    Key? key,
    required this.url,
    this.height,
    this.width,
    this.isCache = false,
  }) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var userTokenModel = ref.watch(authTokenProvider).asData?.value;
    if (url.contains('.svg')) {
      return SvgPicture.network(
        url,
        fit: BoxFit.contain,
        height: height,
        width: width,
      );
    } else {
      if (isCache) {
        return CachedNetworkImage(
          imageUrl: url,
          httpHeaders: {
            HttpHeaders.authorizationHeader: 'Bearer ${userTokenModel?.token}',
          },
          imageBuilder: (context, imageProvider) => Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
          placeholder: (context, url) => _shimmerLoading(),
          errorWidget: (context, url, error) {
            return const Icon(Icons.error);
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
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer ${userTokenModel?.token}',
        },
        loadingBuilder: (context, child, loadingProgress) {
          return loadingProgress == null ? child : _shimmerLoading();
        },
        errorBuilder: (context, error, stackTrace) {
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
      period: Duration(seconds: 1),
      baseColor: ColorConstants.almostBlack,
      highlightColor: ColorConstants.greyIsTheNewBlack,
      child: Container(
        color: ColorConstants.almostBlack,
        height: height,
        width: width,
      ),
    );
  }
}
