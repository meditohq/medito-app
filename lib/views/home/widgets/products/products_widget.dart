import 'package:flutter/material.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/home/product/product_model.dart';
import 'package:medito/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:medito/services/products_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/utils/black_friday_utils.dart';
import 'package:medito/providers/home/widget_order_provider.dart';
import 'package:medito/constants/constants.dart';
import '../home_gradient_border.dart';

class ProductsWidget extends ConsumerStatefulWidget {
  final List<ProductGroupModel>? productGroups;

  const ProductsWidget({super.key, this.productGroups});

  @override
  ConsumerState<ProductsWidget> createState() => _ProductsWidgetState();
}

class _ProductsWidgetState extends ConsumerState<ProductsWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftGradient = false;
  bool _showRightGradient = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollGradients);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollGradients();
    });
  }

  void _updateScrollGradients() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;
    final showLeft = currentScroll > 10;
    final showRight = maxScroll > 0 && currentScroll < maxScroll - 10;

    if (showLeft != _showLeftGradient || showRight != _showRightGradient) {
      setState(() {
        _showLeftGradient = showLeft;
        _showRightGradient = showRight;
      });
    }
  }

  @override
  void didUpdateWidget(ProductsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productGroups != widget.productGroups) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateScrollGradients();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollGradients);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.productGroups == null || widget.productGroups!.isEmpty) {
      AppLogger.d('ProductsWidget', 'No product groups to display');
      return const SizedBox.shrink();
    }

    final isBlackFriday = BlackFridayUtils.isBlackFridayWeek(DateTime.now());
    final prefs = ref.read(sharedPreferencesProvider);
    final isDismissed = BlackFridayUtils.isBlackFridayDismissedSync(prefs);
    final showBlackFridayStyle = isBlackFriday && !isDismissed;

    // Sort product groups - new products first
    final sortedGroups = List<ProductGroupModel>.from(widget.productGroups!)
      ..sort((a, b) {
        // Check if any variant in the group is new
        final aHasNew = a.variants.any((v) => v.isNew);
        final bHasNew = b.variants.any((v) => v.isNew);
        if (aHasNew != bHasNew) return aHasNew ? -1 : 1;
        return 0;
      });

    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openShopUrl(),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            showBlackFridayStyle
                                ? AppLocalizations.of(context)!.blackFridayTitle
                                : AppLocalizations.of(
                                    context,
                                  )!.meditationProducts,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontFamily: 'teachers',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w400,
                                  height: 28 / 24,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                        ),
                        if (!showBlackFridayStyle) ...[
                          const SizedBox(width: 8),
                          MeditoIcon(
                            assetName: MeditoIcons.arrowRight,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (showBlackFridayStyle) ...[
                  const SizedBox(width: 8),
                  Semantics(
                    label: AppLocalizations.of(context)!.dismiss,
                    button: true,
                    child: GestureDetector(
                      onTap: () => _dismissBlackFriday(context, ref),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: ExcludeSemantics(
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showBlackFridayStyle)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                AppLocalizations.of(context)!.blackFridaySubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16, right: 4),
                  itemCount: sortedGroups.length,
                  itemBuilder: (context, index) {
                    final productGroup = sortedGroups[index];
                    return ProductGroupCard(productGroup: productGroup);
                  },
                ),
                if (_showLeftGradient)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 32,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Theme.of(context).scaffoldBackgroundColor,
                              Theme.of(
                                context,
                              ).scaffoldBackgroundColor.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_showRightGradient)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 32,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              Theme.of(context).scaffoldBackgroundColor,
                              Theme.of(
                                context,
                              ).scaffoldBackgroundColor.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (showBlackFridayStyle)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _openShopUrl(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.blackFridaySeeAllButton,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _dismissBlackFriday(BuildContext context, WidgetRef ref) async {
    await BlackFridayUtils.dismissBlackFriday();
    ref.read(homeWidgetOrderProvider.notifier).refreshOrder();
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
  static const _kCardBorderWidth = 0.5;
  static const _kCardBorderRadius = 24.0;

  const ProductGroupCard({super.key, required this.productGroup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasNewVariant = productGroup.variants.any((v) => v.isNew);
    final backgroundColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: cardWidth,
            height: cardWidth,
            child: HomeGradientBorder(
              backgroundColor: backgroundColor,
              borderRadius: _kCardBorderRadius,
              borderWidth: _kCardBorderWidth,
              child: Material(
                color: Colors.transparent,
                child: Semantics(
                  label: productGroup.name,
                  button: true,
                  child: InkWell(
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
                      analytics.logFirstActionAfterOnboardingIfNeeded(
                        'product',
                      );

                      _openProductUrl(productGroup.url);
                      for (final variant in productGroup.variants) {
                        ProductsService().markProductAsSeen(variant.id);
                      }
                    },
                    borderRadius: BorderRadius.circular(
                      _kCardBorderRadius - _kCardBorderWidth,
                    ),
                    child: Stack(
                      children: [
                        if (productGroup.allImageUrls.isNotEmpty)
                          AspectRatio(
                            aspectRatio: 1,
                            child: ProductImageCarousel(
                              productGroup: productGroup,
                              cardWidth: cardWidth,
                            ),
                          )
                        else if (productGroup.imageUrl != null)
                          AspectRatio(
                            aspectRatio: 1,
                            child: CachedNetworkImage(
                              imageUrl: productGroup.imageUrl!,
                              fit: BoxFit.cover,
                              width: cardWidth,
                              key: ValueKey(
                                'product_image_${productGroup.groupId}',
                              ),
                              placeholder: (context, url) => Container(
                                color: Theme.of(context).colorScheme.surface,
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Theme.of(context).colorScheme.surface,
                                child: Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              color: Theme.of(context).colorScheme.surface,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
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
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.newProductLabel,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            productGroup.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: teachers,
              fontSize: 12,
              color: textColor,
            ),
          ),
        ],
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
  List<String> _tshirtImageUrls = [];
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
    _imageUrls = _isTshirt
        ? List<String>.from(_tshirtImageUrls)
        : List<String>.from(widget.productGroup.allImageUrls);
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

    _tshirtImageUrls = [];
    if (!_isTshirt) return;

    final imageByColor = <String, String>{};
    for (final variant in widget.productGroup.variants) {
      final color = variant.color;
      final imageUrl = variant.imageUrl;
      if (color == null || color.isEmpty || imageUrl == null) continue;

      imageByColor.putIfAbsent(color.toLowerCase(), () => imageUrl);
    }

    _tshirtImageUrls = imageByColor.values.toList();
    if (_tshirtImageUrls.isEmpty) {
      _tshirtImageUrls = List<String>.from(widget.productGroup.allImageUrls);
    }

    _tshirtImageUrls.shuffle();
  }

  void _precacheAllImages() {
    for (final url in _imageUrls) {
      // Skip precaching images from dead domains
      if (HTTPConstants.isDeadDomain(url)) {
        continue;
      }

      try {
        precacheImage(CachedNetworkImageProvider(url), context).catchError((
          error,
        ) {
          // Silently handle precaching errors - they're not critical
          AppLogger.d(
            'ProductImageCarousel',
            'Failed to precache image: $url, error: $error',
          );
        });
      } catch (e) {
        // Silently handle any synchronous errors from precaching
        AppLogger.d(
          'ProductImageCarousel',
          'Failed to precache image: $url, error: $e',
        );
      }
    }
  }

  void _startImageTimer() {
    _imageTimer?.cancel();

    if (_imageUrls.length <= 1) return;

    _imageTimer = Timer.periodic(_imageDuration, (timer) {
      if (!mounted) return;

      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _imageUrls.length;
      });
    });
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Container(
        key: ValueKey(
          'product_image_${widget.productGroup.groupId}_$_currentImageIndex',
        ),
        color: Theme.of(context).colorScheme.surface,
        child: CachedNetworkImage(
          imageUrl: currentImageUrl,
          fit: BoxFit.cover,
          imageBuilder: (context, imageProvider) => Container(
            decoration: BoxDecoration(
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
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

  bool get _isTshirt =>
      widget.productGroup.description?.toLowerCase().contains('shirt') ?? false;
}
