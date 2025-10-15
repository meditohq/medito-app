import 'package:flutter/material.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/config_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/home/product/product_model.dart';
import 'package:medito/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:medito/services/products_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/providers.dart';
import 'package:hugeicons/hugeicons.dart';

class ProductsWidget extends StatelessWidget {
  final List<ProductGroupModel>? productGroups;

  const ProductsWidget({
    super.key,
    this.productGroups,
  });

  @override
  Widget build(BuildContext context) {
    if (productGroups == null || productGroups!.isEmpty) {
      AppLogger.d('ProductsWidget', 'No product groups to display');
      return const SizedBox.shrink();
    }

    // Sort product groups - new products first
    final sortedGroups = List<ProductGroupModel>.from(productGroups!)
      ..sort((a, b) {
        // Check if any variant in the group is new
        final aHasNew = a.variants.any((v) => v.isNew);
        final bHasNew = b.variants.any((v) => v.isNew);
        if (aHasNew != bHasNew) return aHasNew ? -1 : 1;
        return 0;
      });

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => _openShopUrl(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!.meditationProducts,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontFamily: 'teachers',
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          height: 28 / 24,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    HugeIcons.solidSharpArrowRight02,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 16,
                  ),
                ],
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
              itemCount: sortedGroups.length,
              itemBuilder: (context, index) {
                final productGroup = sortedGroups[index];
                return ProductGroupCard(productGroup: productGroup);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openShopUrl() async {
    final uri = Uri.parse(ConfigConstants.shopUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class ProductGroupCard extends ConsumerWidget {
  final ProductGroupModel productGroup;
  final double cardWidth = 150.0;

  const ProductGroupCard({
    super.key,
    required this.productGroup,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasNewVariant = productGroup.variants.any((v) => v.isNew);

    return GestureDetector(
      onTap: () async {
        // Log analytics event
        var analytics = ref.read(analyticsServiceProvider);

        analytics.logEvent(
          name: AnalyticsEventConstants.productClicked,
          parameters: {
            'group_id': productGroup.groupId,
            'name': productGroup.name,
            'url': productGroup.url ?? '',
          },
        );

        _openProductUrl(productGroup.url);
        for (final variant in productGroup.variants) {
          ProductsService().markProductAsSeen(variant.id);
        }
      },
      child: SizedBox(
        width: cardWidth,
        child: Card(
          margin: const EdgeInsets.only(right: 12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
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
                            key: ValueKey(
                                'product_image_${productGroup.groupId}'),
                            placeholder: (context, url) => Container(
                              color: Theme.of(context).colorScheme.surface,
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Theme.of(context).colorScheme.surface,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
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
                            color: Theme.of(context).colorScheme.surface,
                            child: Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (hasNewVariant)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.newProductLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ),
                ],
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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
  List<String> _imageUrls = [];

  @override
  void initState() {
    super.initState();
    _organizeImages();
    _updateImageUrls();
    _startImageTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheAllImages();
  }

  void _updateImageUrls() {
    final isTshirt =
        widget.productGroup.description?.toLowerCase().contains('shirt') ??
            false;
    _imageUrls = isTshirt
        ? _tshirtVariants.map((v) => v['imageUrl'] as String).toList()
        : widget.productGroup.allImageUrls;
  }

  @override
  void didUpdateWidget(ProductImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productGroup != widget.productGroup) {
      _organizeImages();
      setState(() {
        _updateImageUrls();
      });
      _precacheAllImages();
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

  void _precacheAllImages() {
    for (final url in _imageUrls) {
      try {
        precacheImage(CachedNetworkImageProvider(url), context)
            .catchError((error) {
          // Silently handle precaching errors - they're not critical
          AppLogger.d('ProductImageCarousel',
              'Failed to precache image: $url, error: $error');
        });
      } catch (e) {
        // Silently handle any synchronous errors from precaching
        AppLogger.d('ProductImageCarousel',
            'Failed to precache image: $url, error: $e');
      }
    }
  }

  void _startImageTimer() {
    // Cancel any existing timer
    _imageTimer?.cancel();

    final imageList = _imageUrls;

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
    if (_imageUrls.isEmpty) {
      // If no images available, show placeholder
      return Container(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }

    // Make sure current index is within bounds for the active list
    if (_currentImageIndex >= _imageUrls.length) {
      _currentImageIndex = 0; // Reset to first image if out of bounds
    }

    // Get current image URL (with bounds checking)
    final String currentImageUrl = _imageUrls[_currentImageIndex];

    // Reset the timer if needed
    if (_imageTimer == null && _imageUrls.length > 1) {
      _startImageTimer();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Container(
        key: ValueKey(
            'product_image_${widget.productGroup.groupId}_$_currentImageIndex'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.0),
          color: Theme.of(context).colorScheme.surface,
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: currentImageUrl,
          fit: BoxFit.cover,
          imageBuilder: (context, imageProvider) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
          placeholder: (context, url) => Container(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
