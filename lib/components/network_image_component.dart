import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';

class NetworkImageComponent extends StatelessWidget {
  final String url;
  final double? height, width;
  const NetworkImageComponent(
      {Key? key, required this.url, this.height, this.width})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    if (url.contains('.svg')) {
      return SvgPicture.network(
        url,
        fit: BoxFit.contain,
        height: height,
        width: width,
      );
    } else {
      return Image.network(
        url,
        fit: BoxFit.cover,
        height: height,
        width: width,
        cacheHeight: height?.round(),
        cacheWidth: width?.round(),
        headers: {
          HttpHeaders.authorizationHeader: HTTPConstants.CONTENT_TOKEN,
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          } else {
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
}
