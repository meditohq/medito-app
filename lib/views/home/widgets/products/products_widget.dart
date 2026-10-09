import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/shop/shop_models.dart';
import 'package:medito/providers/home/widget_order_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/shop/fourthwall_service.dart';
import 'package:medito/utils/black_friday_utils.dart';
import 'package:medito/providers/shop/shop_providers.dart';
import 'package:medito/views/shop/bag_sheet.dart';
import 'package:medito/views/shop/shop_navigation.dart';
import 'package:medito/views/shop/widgets/shop_photo.dart';
import 'package:medito/views/shop/widgets/shop_product_card.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/shimmers/widgets/box_shimmer_widget.dart';

import '../../home_styles.dart';
import '../home_gradient_border.dart';

const _tileWidth = 148.0;
const _tileGap = 12.0;
const _photoHeight = _tileWidth / kShopPhotoAspect;
const _captionHeight = 52.0;

/// Height of the tile strip, shared with the loading placeholder so the
/// section doesn't jump when products arrive.
const kHomeShopStripHeight = _photoHeight + _captionHeight;

/// "Shop to Support" row on Home: a horizontal strip of shop products with
/// local prices, ending in a "See all" tile. Tapping opens the native shop.
class ProductsWidget extends ConsumerWidget {
  const ProductsWidget({super.key, required this.products});

  /// Null while loading: renders the header over skeleton tiles.
  final List<ShopProduct>? products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final prefs = ref.read(sharedPreferencesProvider);
    final showBlackFridayStyle =
        BlackFridayUtils.isBlackFridayWeek(DateTime.now()) &&
        !BlackFridayUtils.isBlackFridayDismissedSync(prefs);

    void openAll() =>
        openShop(context, source: AnalyticsEventConstants.sourceHomeHeader);

    final products = this.products;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // The See all button brings its own padding on the right.
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            children: [
              Expanded(
                // A heading, so screen-reader users can jump between Home
                // sections; still opens the shop.
                child: Semantics(
                  header: true,
                  button: true,
                  child: GestureDetector(
                    onTap: openAll,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      showBlackFridayStyle
                          ? l10n.blackFridayTitle
                          : l10n.meditationProducts,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        height: 28 / 24,
                        color: onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              _BagPill(onBrowse: openAll),
              if (showBlackFridayStyle)
                IconButton(
                  tooltip: l10n.dismiss,
                  onPressed: () async {
                    await BlackFridayUtils.dismissBlackFriday();
                    ref.read(homeWidgetOrderProvider.notifier).refreshOrder();
                  },
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                )
              else
                TextButton(
                  onPressed: openAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.shopSeeAll),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (showBlackFridayStyle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              l10n.blackFridaySubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 14,
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: kHomeShopStripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products == null ? 4 : products.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: _tileGap),
            itemBuilder: (context, index) {
              if (products == null) return const _SkeletonTile();
              if (index == products.length) {
                return _SeeAllTile(onTap: openAll);
              }
              return _ProductTile(
                product: products[index],
                // Stagger the colour cycling so tiles don't all flip at once.
                cycleOffset: Duration(milliseconds: 1300 * index),
              );
            },
          ),
        ),
        if (showBlackFridayStyle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: openAll,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(l10n.blackFridaySeeAllButton),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product, required this.cycleOffset});

  final ShopProduct product;
  final Duration cycleOffset;

  void _open(BuildContext context, WidgetRef ref) {
    final analytics = ref.read(analyticsServiceProvider);
    analytics.logEvent(
      name: AnalyticsEventConstants.productClicked,
      parameters: {
        'group_id': product.id,
        'name': product.name,
        'url': FourthwallService.productWebUri(product.slug).toString(),
      },
    );
    analytics.logFirstActionAfterOnboardingIfNeeded('product');
    openShopProduct(
      context,
      slug: product.slug,
      product: product,
      source: AnalyticsEventConstants.sourceHomeCard,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final price = product.fromPrice;
    final priceLabel = price == null
        ? ''
        : product.hasVariedPrices
        ? l10n.shopFromPrice(price.format())
        : price.format();

    return Semantics(
      button: true,
      // The label hides the photo's "New" pill, so carry it here.
      label:
          '${product.name}, $priceLabel'
          '${product.isNewAt(DateTime.now()) ? ', ${l10n.newProductLabel}' : ''}',
      excludeSemantics: true,
      // excludeSemantics drops the child's tap action, so give it here.
      onTap: () => _open(context, ref),
      child: GestureDetector(
        onTap: () => _open(context, ref),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _tileWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _photoHeight,
                child: HomeGradientBorder(
                  backgroundColor: theme.cardColor,
                  borderRadius: kHomeTileRadius,
                  borderWidth: 0.5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _CyclingPhoto(
                        urls: product.showcaseImages.map((i) => i.url).toList(),
                        offset: cycleOffset,
                      ),
                      if (product.isNewAt(DateTime.now()))
                        Positioned(
                          left: 8,
                          top: 8,
                          child: ShopPill(label: l10n.newProductLabel),
                        ),
                      Positioned.fill(
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(onTap: () => _open(context, ref)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: onSurface,
                    height: 1.3,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  priceLabel,
                  maxLines: 1,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Crossfades through one photo per colour, so a shirt that comes in six
/// colours shows them off without a tap.
class _CyclingPhoto extends StatefulWidget {
  const _CyclingPhoto({required this.urls, required this.offset});

  final List<String> urls;
  final Duration offset;

  @override
  State<_CyclingPhoto> createState() => _CyclingPhotoState();
}

class _CyclingPhotoState extends State<_CyclingPhoto> {
  static const _interval = Duration(seconds: 8);

  int _index = 0;
  Timer? _start;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.urls.length > 1) {
      _start = Timer(_interval + widget.offset, () {
        _advance();
        _timer = Timer.periodic(_interval, (_) => _advance());
      });
    }
  }

  void _advance() {
    if (!mounted) return;
    setState(() => _index = (_index + 1) % widget.urls.length);
  }

  @override
  void dispose() {
    _start?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    if (urls.isEmpty) return const ShopPhoto(url: null);
    final url = urls[_index % urls.length];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: ShopPhoto(key: ValueKey(url), url: url),
    );
  }
}

class _SeeAllTile extends StatelessWidget {
  const _SeeAllTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return SizedBox(
      width: _tileWidth,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: _photoHeight,
          child: HomeGradientBorder(
            backgroundColor: theme.cardColor,
            borderRadius: kHomeTileRadius,
            borderWidth: 0.5,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: onSurface.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: MeditoIcon(
                            assetName: MeditoIcons.arrowRight,
                            color: onSurface,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.shopSeeAll,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: _tileWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BoxShimmerWidget(
            width: _tileWidth,
            height: _photoHeight,
            borderRadius: kHomeTileRadius,
          ),
          SizedBox(height: 12),
          BoxShimmerWidget(width: 110, height: 12, borderRadius: 6),
          SizedBox(height: 8),
          BoxShimmerWidget(width: 60, height: 12, borderRadius: 6),
        ],
      ),
    );
  }
}

/// Bag count, shown on Home only while something is in the bag: the way back
/// to an unfinished order, without turning Home into a storefront.
class _BagPill extends ConsumerWidget {
  const _BagPill({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(shopBagProvider.select((b) => b.quantity));
    if (count == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Semantics(
        button: true,
        label: '${l10n.shopViewBag}, ${l10n.shopBagItemCount(count)}',
        excludeSemantics: true,
        // excludeSemantics drops the InkWell's tap action, so give it here.
        onTap: () => showShopBag(
          context,
          source: AnalyticsEventConstants.sourceHomeCard,
          onBrowse: onBrowse,
        ),
        child: Material(
          color: theme.cardColor,
          shape: StadiumBorder(
            side: BorderSide(color: onSurface.withValues(alpha: 0.15)),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => showShopBag(
              context,
              source: AnalyticsEventConstants.sourceHomeCard,
              onBrowse: onBrowse,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MeditoIcon(
                    assetName: MeditoIcons.shop,
                    color: onSurface,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
