import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:medito/constants/constants.dart';
import 'package:shimmer/shimmer.dart';

class NetworkImageWidget extends StatelessWidget {
  final String url;
  final double? height, width;
  final bool shouldCache;
  final Gradient? gradient;
  final Widget? errorWidget;
  const NetworkImageWidget({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.shouldCache = false,
    this.gradient,
    this.errorWidget,
  });

  static final Map<double, String> _resolutionSuffixes = {
    3.0: '_3x.webp',
    2.0: '_2x.webp',
    1.0: '_1x.webp',
  };

  String _getWebPImageUrl(BuildContext context, String imagePath) {
    var pixelRatio = MediaQuery.of(context).devicePixelRatio;
    var suffix = _resolutionSuffixes.entries
        .firstWhere(
          (entry) => pixelRatio >= entry.key,
          orElse: () => _resolutionSuffixes.entries.last,
        )
        .value;

    return '$contentBaseUrl$imagePath$suffix';
  }

  @override
  Widget build(BuildContext context) {
    // Skip loading images from dead domains
    if (HTTPConstants.isDeadDomain(url)) {
      return errorWidget ??
          Image.asset(AssetConstants.placeholder, fit: BoxFit.cover);
    }

    var scaledImageUrl = url.startsWith('http')
        ? url
        : _getWebPImageUrl(context, url);
    var originalImageUrl = url.startsWith('http') ? url : '$contentBaseUrl$url';

    return scaledImageUrl.endsWith('.svg')
        ? _buildSvgImage(scaledImageUrl)
        : shouldCache
        ? _buildCachedImage(scaledImageUrl, originalImageUrl)
        : _buildNetworkImage(scaledImageUrl, originalImageUrl);
  }

  Widget _buildSvgImage(String url) {
    return SvgPicture.network(
      url,
      fit: BoxFit.contain,
      height: height,
      width: width,
      placeholderBuilder: (context) => _shimmerLoading(),
    );
  }

  Widget _buildCachedImage(String scaledUrl, String originalUrl) {
    return CachedNetworkImage(
      imageUrl: scaledUrl,
      imageBuilder: (context, imageProvider) => Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
        foregroundDecoration: BoxDecoration(gradient: gradient),
      ),
      placeholder: (_, _) => _shimmerLoading(),
      errorWidget: (context, url, error) {
        // If scaled image fails, try original
        if (url != originalUrl) {
          return CachedNetworkImage(
            imageUrl: originalUrl,
            imageBuilder: (context, imageProvider) => Container(
              decoration: BoxDecoration(
                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
              ),
              foregroundDecoration: BoxDecoration(gradient: gradient),
            ),
            placeholder: (_, _) => _shimmerLoading(),
            errorWidget: (context, url, error) =>
                errorWidget ??
                Image.asset(AssetConstants.placeholder, fit: BoxFit.cover),
          );
        }
        return errorWidget ??
            Image.asset(AssetConstants.placeholder, fit: BoxFit.cover);
      },
    );
  }

  Widget _buildNetworkImage(String scaledUrl, String originalUrl) {
    return Image.network(
      scaledUrl,
      fit: BoxFit.cover,
      height: height,
      width: width,
      cacheHeight: height?.round(),
      cacheWidth: width?.round(),
      loadingBuilder: (_, child, loadingProgress) =>
          loadingProgress == null ? child : _shimmerLoading(),
      errorBuilder: (context, error, stackTrace) {
        // If scaled image fails, try original
        if (scaledUrl != originalUrl) {
          return Image.network(
            originalUrl,
            fit: BoxFit.cover,
            height: height,
            width: width,
            cacheHeight: height?.round(),
            cacheWidth: width?.round(),
            loadingBuilder: (_, child, loadingProgress) =>
                loadingProgress == null ? child : _shimmerLoading(),
            errorBuilder: (context, error, stackTrace) =>
                errorWidget ??
                Image.asset(AssetConstants.placeholder, fit: BoxFit.cover),
          );
        }
        return errorWidget ??
            Image.asset(AssetConstants.placeholder, fit: BoxFit.cover);
      },
    );
  }

  Widget _shimmerLoading() {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final baseColor = isDark
            ? ColorConstants.greyIsTheNewGrey
            : ColorConstants.lightGrey;
        final backgroundColor = isDark
            ? ColorConstants.onyx
            : ColorConstants.lightCard;

        return Shimmer.fromColors(
          period: const Duration(seconds: 1),
          baseColor: baseColor,
          highlightColor: backgroundColor,
          child: Container(
            color: backgroundColor,
            height: height,
            width: width,
          ),
        );
      },
    );
  }
}
