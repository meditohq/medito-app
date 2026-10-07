import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/shop/shop_models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/shop/shop_providers.dart';
import 'package:medito/services/shop/fourthwall_service.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/shop/bag_sheet.dart';
import 'package:medito/views/shop/shop_navigation.dart';
import 'package:medito/views/shop/widgets/shop_error_view.dart';
import 'package:medito/views/shop/widgets/shop_product_card.dart';
import 'package:medito/widgets/adaptive/adaptive_page_body.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/shimmers/widgets/box_shimmer_widget.dart';

/// Native storefront for shop.medito.app: collection filter, product grid,
/// bag. Checkout hands off to Fourthwall.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key, required this.source});

  /// Analytics: where the user came from (AnalyticsEventConstants.source*).
  final String source;

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _scrollController = ScrollController();
  String _collection = FourthwallService.allCollection;

  static const _gridSpacing = 12.0;
  static const _minTileWidth = 160.0;
  static const _loadMoreThreshold = 800.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: AnalyticsEventConstants.shopViewed,
          parameters: {'source': widget.source},
        );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    // After a failed page the footer's retry button takes over; retrying on
    // every scroll tick would hammer a failing API.
    final listing = ref.read(shopListingProvider(_collection)).value;
    if (listing == null || listing.loadMoreFailed) return;
    if (_scrollController.position.extentAfter < _loadMoreThreshold) {
      ref.read(shopListingProvider(_collection).notifier).loadMore();
    }
  }

  void _selectCollection(String slug) {
    if (slug == _collection) return;
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: AnalyticsEventConstants.shopCollectionSelected,
          parameters: {'collection': slug},
        );
    setState(() => _collection = slug);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _refresh() async {
    ref.invalidate(shopListingProvider(_collection));
    ref.invalidate(shopCollectionsProvider);
    await ref.read(shopListingProvider(_collection).future);
  }

  void _openProduct(ShopProduct product) {
    openShopProduct(
      context,
      slug: product.slug,
      product: product,
      source: AnalyticsEventConstants.sourceShopGrid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final listing = ref.watch(shopListingProvider(_collection));

    // A short first page may not fill the viewport, so there is nothing to
    // scroll; check once the frame is laid out.
    if (listing.value?.hasNextPage ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeLoadMore();
      });
    }

    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                tooltip: l10n.goBack,
                onPressed: () => Navigator.pop(context),
                icon: MeditoIcon(
                  assetName: MeditoIcons.arrowLeft,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              const ShopBagButton(
                source: AnalyticsEventConstants.sourceShopGrid,
              ),
            ],
          ),
        ),
      ),
      body: AdaptivePageBody(
        maxWidth: 1100,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  centerTitle: false,
                  automaticallyImplyLeading: false,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  surfaceTintColor: Colors.transparent,
                  toolbarHeight: 56,
                  pinned: true,
                  elevation: 0,
                  title: HomeHeaderWidget(greeting: l10n.shopTitle),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      l10n.shopSubtitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CollectionChips(
                    selected: _collection,
                    onSelected: _selectCollection,
                  ),
                ),
                ...listing.when(
                  skipLoadingOnRefresh: true,
                  loading: () => [const _GridSkeleton()],
                  error: (error, _) => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ShopErrorView(
                        surface: 'grid',
                        error: error,
                        onRetry: () =>
                            ref.invalidate(shopListingProvider(_collection)),
                      ),
                    ),
                  ],
                  data: (data) => [
                    _ProductGrid(products: data.products, onTap: _openProduct),
                    SliverToBoxAdapter(
                      child: _ListingFooter(
                        listing: data,
                        onRetry: () => ref
                            .read(shopListingProvider(_collection).notifier)
                            .loadMore(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Picks a column count for the width and sizes tiles to photo + caption.
SliverGridDelegate _gridDelegate(double width) {
  final columns =
      ((width + _ShopScreenState._gridSpacing) /
              (_ShopScreenState._minTileWidth + _ShopScreenState._gridSpacing))
          .floor()
          .clamp(2, 6);
  final tileWidth =
      (width - _ShopScreenState._gridSpacing * (columns - 1)) / columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: _ShopScreenState._gridSpacing,
    mainAxisSpacing: 8,
    mainAxisExtent: tileWidth / kShopPhotoAspect + kShopCardCaptionHeight,
  );
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products, required this.onTap});

  final List<ShopProduct> products;
  final ValueChanged<ShopProduct> onTap;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) => SliverGrid(
          gridDelegate: _gridDelegate(constraints.crossAxisExtent),
          delegate: SliverChildBuilderDelegate(
            (context, index) => ShopProductCard(
              product: products[index],
              onTap: () => onTap(products[index]),
            ),
            childCount: products.length,
          ),
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) => SliverGrid(
          gridDelegate: _gridDelegate(constraints.crossAxisExtent),
          delegate: SliverChildBuilderDelegate(
            (context, _) => LayoutBuilder(
              builder: (context, box) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BoxShimmerWidget(
                    width: box.maxWidth,
                    height: box.maxWidth / kShopPhotoAspect,
                    borderRadius: 16,
                  ),
                  const SizedBox(height: 12),
                  BoxShimmerWidget(
                    width: box.maxWidth * 0.8,
                    height: 12,
                    borderRadius: 6,
                  ),
                  const SizedBox(height: 8),
                  BoxShimmerWidget(
                    width: box.maxWidth * 0.35,
                    height: 12,
                    borderRadius: 6,
                  ),
                ],
              ),
            ),
            childCount: 6,
          ),
        ),
      ),
    );
  }
}

class _ListingFooter extends StatelessWidget {
  const _ListingFooter({required this.listing, required this.onRetry});

  final ShopListing listing;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    Widget? child;
    if (listing.isLoadingMore) {
      child = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: onSurface),
      );
    } else if (listing.loadMoreFailed) {
      child = TextButton(onPressed: onRetry, child: Text(l10n.retry));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Center(child: child ?? const SizedBox(height: 24)),
    );
  }
}

class _CollectionChips extends ConsumerWidget {
  const _CollectionChips({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final collections = ref.watch(shopCollectionsProvider).value ?? const [];
    final chips = <(String, String)>[
      (FourthwallService.allCollection, l10n.shopAllCollection),
      for (final c in collections)
        // The curated Home collection is plumbing, not a category.
        if (c.slug != FourthwallService.allCollection &&
            c.slug != FourthwallService.homeCollection)
          (c.slug, c.name),
    ];
    // "All" alone isn't a filter; keep the space so the grid doesn't jump
    // when collections arrive.
    if (chips.length == 1) return const SizedBox(height: 60);

    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (slug, name) = chips[index];
          return ShopChoicePill(
            label: name,
            selected: slug == selected,
            onTap: () => onSelected(slug),
          );
        },
      ),
    );
  }
}

/// Stadium pill used for collection filters and size/option choices.
class ShopChoicePill extends StatelessWidget {
  const ShopChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.minWidth = 0,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final double minWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected
        ? scheme.onPrimary
        : scheme.onSurface.withValues(alpha: enabled ? 1 : 0.35);

    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      child: Material(
        color: selected ? scheme.primary : theme.cardColor,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? scheme.primary
                : scheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth, minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    decoration: enabled ? null : TextDecoration.lineThrough,
                    decorationColor: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
