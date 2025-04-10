import 'package:flutter/material.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/strings/string_constants.dart';
import 'package:medito/models/home/product/product_model.dart';
import 'package:medito/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

class ProductsWidget extends StatelessWidget {
  final List<ProductGroupModel>? productGroups;

  const ProductsWidget({
    super.key,
    this.productGroups,
  });

  @override
  Widget build(BuildContext context) {
    AppLogger.d('ProductsWidget',
        'build called, productGroups: ${productGroups?.length ?? 0}');

    if (productGroups == null || productGroups!.isEmpty) {
      AppLogger.d('ProductsWidget', 'No product groups to display');
      return const SizedBox.shrink();
    }

    AppLogger.d(
        'ProductsWidget', 'Rendering ${productGroups!.length} product groups');
    if (productGroups!.isNotEmpty) {
      AppLogger.d('ProductsWidget',
          'First product group - ${productGroups![0].name}, variants: ${productGroups![0].variants.length}');
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text(
              StringConstants.meditationProducts,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w400,
                fontFamily: 'teachers',
                fontSize: 20,
                height: 28 / 24,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.builder(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: productGroups!.length,
              itemBuilder: (context, index) {
                final productGroup = productGroups![index];
                AppLogger.d('ProductsWidget',
                    'Building product group card for ${productGroup.name} at index $index');
                return ProductGroupCard(productGroup: productGroup);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductGroupCard extends StatelessWidget {
  final ProductGroupModel productGroup;
  final double cardWidth = 150.0;

  const ProductGroupCard({
    super.key,
    required this.productGroup,
  });

  @override
  Widget build(BuildContext context) {
    // Sort variants by price
    final sortedVariants = List<ProductModel>.from(productGroup.variants)
      ..sort((a, b) => a.price.compareTo(b.price));

    return GestureDetector(
      onTap: () => _openProductUrl(productGroup.url),
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: ColorConstants.onyx,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (productGroup.allImageUrls.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: ProductImageCarousel(
                      productGroup: productGroup,
                      cardWidth: cardWidth,
                    ),
                  ),
                ),
              )
            else if (productGroup.imageUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: CachedNetworkImage(
                      imageUrl: productGroup.imageUrl!,
                      fit: BoxFit.cover,
                      width: cardWidth,
                      key: ValueKey('product_image_${productGroup.groupId}'),
                      placeholder: (context, url) => Container(
                        color: ColorConstants.charcoal,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: ColorConstants.charcoal,
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: ColorConstants.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Container(
                      color: ColorConstants.charcoal,
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: ColorConstants.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productGroup.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ColorConstants.white.withOpacity(0.7),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProductUrl(String? url) async {
    if (url == null) return;

    var uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class ProductImageCarousel extends StatefulWidget {
  final ProductGroupModel productGroup;
  final double cardWidth;

  const ProductImageCarousel({
    super.key,
    required this.productGroup,
    required this.cardWidth,
  });

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  int _currentImageIndex = 0;
  Timer? _imageTimer;
  final _imageDuration = const Duration(seconds: 10);
  List<Map<String, dynamic>> _tshirtVariants = [];

  @override
  void initState() {
    super.initState();
    _organizeImages();
    _startImageTimer();
  }

  @override
  void didUpdateWidget(ProductImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productGroup != widget.productGroup) {
      _organizeImages();
      _startImageTimer();
    }
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    super.dispose();
  }

  void _organizeImages() {
    _currentImageIndex = 0; // Reset index when organizing images

    // Check if this is a t-shirt
    final isTshirt =
        widget.productGroup.description?.toLowerCase().contains('shirt') ??
            false;

    if (isTshirt) {
      // Create organized variants for t-shirts with color information
      _tshirtVariants = [];

      // Map between colors and their images
      final colorMap = <String, List<String>>{};

      // Organize variants by color
      for (final variant in widget.productGroup.variants) {
        if (variant.color != null &&
            variant.color!.isNotEmpty &&
            variant.imageUrl != null) {
          final colorKey = variant.color!.toLowerCase();
          colorMap.putIfAbsent(colorKey, () => []);
          colorMap[colorKey]!.add(variant.imageUrl!);
        }
      }

      // If colors are organized, create a list of variant data
      if (colorMap.isNotEmpty) {
        for (final entry in colorMap.entries) {
          _tshirtVariants.add({
            'color': entry.key,
            'imageUrl': entry.value.first, // Use first image for this color
          });
        }
      }

      // If we couldn't organize by color, fall back to all images for this product
      if (_tshirtVariants.isEmpty) {
        for (final url in widget.productGroup.allImageUrls) {
          _tshirtVariants.add({
            'color': 'unknown',
            'imageUrl': url,
          });
        }
      }

      // Shuffle the t-shirt variants to show different colors in random order
      _tshirtVariants.shuffle();
    }
  }

  void _startImageTimer() {
    // Cancel any existing timer
    _imageTimer?.cancel();

    final isTshirt =
        widget.productGroup.description?.toLowerCase().contains('shirt') ??
            false;
    final imageList =
        isTshirt ? _tshirtVariants : widget.productGroup.allImageUrls;

    // Start a new timer if we have multiple images
    if (imageList.length > 1) {
      _imageTimer = Timer.periodic(_imageDuration, (timer) {
        if (mounted) {
          setState(() {
            // Move to next image, loop back to 0 if needed
            _currentImageIndex = (_currentImageIndex + 1) % imageList.length;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is a t-shirt
    final isTshirt =
        widget.productGroup.description?.toLowerCase().contains('shirt') ??
            false;

    // Get appropriate list to use
    final List<String> imageUrls = isTshirt
        ? _tshirtVariants.map((v) => v['imageUrl'] as String).toList()
        : widget.productGroup.allImageUrls;

    if (imageUrls.isEmpty) {
      // If no images available, show placeholder
      return Container(
        color: ColorConstants.charcoal,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: ColorConstants.white,
          ),
        ),
      );
    }

    // Make sure current index is within bounds for the active list
    if (_currentImageIndex >= imageUrls.length) {
      _currentImageIndex = 0; // Reset to first image if out of bounds
    }

    // Get current image URL (with bounds checking)
    final String currentImageUrl = imageUrls[_currentImageIndex];

    // Reset the timer if needed
    if (_imageTimer == null && imageUrls.length > 1) {
      _startImageTimer();
    }

    // Pre-cache all images when building the widget to avoid loading spinners
    for (final url in imageUrls) {
      precacheImage(CachedNetworkImageProvider(url), context);
    }

    return Stack(
      children: [
        // Invisible layer for all images to preload them
        Stack(
          children: imageUrls.map((url) {
            return Opacity(
              opacity: 0.0, // Completely invisible
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: widget.cardWidth,
              ),
            );
          }).toList(),
        ),
        // Visible animated layer
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Stack(
            key: ValueKey(
                'product_image_${widget.productGroup.groupId}_$_currentImageIndex'),
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(currentImageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
