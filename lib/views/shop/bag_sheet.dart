import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/shop/shop_models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/shop/shop_providers.dart';
import 'package:medito/views/home/home_styles.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/views/shop/product_screen.dart';
import 'package:medito/views/shop/shop_navigation.dart';
import 'package:medito/views/shop/widgets/shop_photo.dart';
import 'package:medito/views/shop/widgets/shop_product_card.dart';
import 'package:medito/widgets/medito_icon.dart';

/// Opens the bag. [onBrowse] backs the empty state's "Browse the shop"
/// button; leave it null where the shop is already underneath.
Future<void> showShopBag(
  BuildContext context, {
  required String source,
  VoidCallback? onBrowse,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
    builder: (_) => ShopBagSheet(source: source, onBrowse: onBrowse),
  );
}

/// Bag icon with a unit count badge; opens [showShopBag].
class ShopBagButton extends ConsumerWidget {
  const ShopBagButton({super.key, required this.source, this.onBrowse});

  /// Where the button sits, for [AnalyticsEventConstants.shopBagViewed].
  final String source;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(shopBagProvider.select((b) => b.quantity));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      tooltip: l10n.shopViewBag,
      onPressed: () => showShopBag(context, source: source, onBrowse: onBrowse),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: theme.colorScheme.primary,
        textColor: theme.colorScheme.onPrimary,
        child: MeditoIcon(
          assetName: MeditoIcons.shop,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class ShopBagSheet extends ConsumerStatefulWidget {
  const ShopBagSheet({super.key, required this.source, this.onBrowse});

  final String source;
  final VoidCallback? onBrowse;

  @override
  ConsumerState<ShopBagSheet> createState() => _ShopBagSheetState();
}

/// The bag's contents as event params, shared by the bag-level events.
Map<String, Object> _bagParams(ShopBag bag, {Map<String, Object>? extra}) => {
  ...?extra,
  'items': bag.items.length,
  'quantity': bag.quantity,
  'value': bag.subtotal?.value ?? 0,
  'currency': bag.subtotal?.currency ?? '',
};

class _ShopBagSheetState extends ConsumerState<ShopBagSheet> {
  @override
  void initState() {
    super.initState();
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: AnalyticsEventConstants.shopBagViewed,
          parameters: _bagParams(
            ref.read(shopBagProvider),
            extra: {'source': widget.source},
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final bag = ref.watch(shopBagProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shopBagTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: onSurface,
                  ),
                ),
                if (!bag.isEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.shopBagItemCount(bag.quantity),
                    style: theme.textTheme.titleMedium?.copyWith(color: muted),
                  ),
                ],
              ],
            ),
          ),
          if (bag.isEmpty)
            _EmptyBag(onBrowse: widget.onBrowse)
          else ...[
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (bag.checkoutStarted) const _CheckoutReturnCard(),
                  for (final (i, item) in bag.items.indexed) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: onSurface.withValues(alpha: 0.08),
                      ),
                    _BagLine(item: item),
                  ],
                  const _AddOns(),
                ],
              ),
            ),
            _BagFooter(bag: bag),
          ],
        ],
      ),
    );
  }
}

class _BagLine extends ConsumerWidget {
  const _BagLine({required this.item});

  final BagItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final notifier = ref.read(shopBagProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            height: 64 * 4 / 3,
            child: HomeGradientBorder(
              backgroundColor: theme.colorScheme.surface,
              borderRadius: 12,
              borderWidth: 0.5,
              child: ShopPhoto(url: item.imageUrl),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.total.format(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (item.variantLabel.isNotEmpty)
                  Text(
                    item.variantLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                const SizedBox(height: 10),
                _QuantityStepper(
                  quantity: item.quantity,
                  onChanged: (q) {
                    ref
                        .read(analyticsServiceProvider)
                        .logEvent(
                          name: q <= 0
                              ? AnalyticsEventConstants.shopBagItemRemoved
                              : AnalyticsEventConstants.shopBagQuantityChanged,
                          parameters: {
                            'product_slug': item.productSlug,
                            'variant_id': item.variantId,
                            if (q <= 0) 'quantity': item.quantity,
                            if (q > 0) 'from': item.quantity,
                            if (q > 0) 'to': q,
                          },
                        );
                    notifier.setQuantity(item.variantId, q);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// − n + pill. At one, the minus becomes a bin so the last tap removes.
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final canIncrease = quantity < ShopBagNotifier.maxQuantity;

    Widget button({
      required IconData icon,
      required String label,
      required VoidCallback? onTap,
    }) => IconButton(
      onPressed: onTap,
      tooltip: label,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 40, height: 36),
      padding: EdgeInsets.zero,
      color: onSurface,
      disabledColor: onSurface.withValues(alpha: 0.3),
      icon: Icon(icon),
    );

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(color: onSurface.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            icon: quantity == 1
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            label: quantity == 1
                ? l10n.shopRemoveItem
                : l10n.shopDecreaseQuantity,
            onTap: () => onChanged(quantity - 1),
          ),
          SizedBox(
            width: 20,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          button(
            icon: Icons.add_rounded,
            label: l10n.shopIncreaseQuantity,
            onTap: canIncrease ? () => onChanged(quantity + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// We can't see whether checkout finished, so after a trip there the bag
/// offers to clear itself rather than guessing.
class _CheckoutReturnCard extends ConsumerStatefulWidget {
  const _CheckoutReturnCard();

  @override
  ConsumerState<_CheckoutReturnCard> createState() =>
      _CheckoutReturnCardState();
}

class _CheckoutReturnCardState extends ConsumerState<_CheckoutReturnCard> {
  @override
  void initState() {
    super.initState();
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: AnalyticsEventConstants.shopCheckoutReturned,
          parameters: _bagParams(ref.read(shopBagProvider)),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HomeGradientBorder(
        backgroundColor: theme.colorScheme.surface,
        borderRadius: kHomeTileRadius,
        borderWidth: 0.5,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.shopCheckoutPrompt,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref
                      .read(analyticsServiceProvider)
                      .logEvent(
                        name: AnalyticsEventConstants.shopBagCleared,
                        parameters: _bagParams(
                          ref.read(shopBagProvider),
                          extra: {'reason': 'checkout_return'},
                        ),
                      );
                  ref.read(shopBagProvider.notifier).clear();
                },
                style: TextButton.styleFrom(
                  textStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(l10n.shopClearBag),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BagFooter extends ConsumerWidget {
  const _BagFooter({required this.bag});

  final ShopBag bag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.shopSubtotal,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: onSurface,
                      ),
                    ),
                  ),
                  Text(
                    bag.subtotal?.format() ?? '',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.shopShippingNote,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => startShopCheckout(ref),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.shopCheckout),
                    ],
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

class _EmptyBag extends StatelessWidget {
  const _EmptyBag({this.onBrowse});

  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          children: [
            MeditoIcon(
              assetName: MeditoIcons.shop,
              color: onSurface.withValues(alpha: 0.4),
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.shopBagEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.shopBagEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (onBrowse != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onBrowse!();
                },
                child: Text(l10n.shopBrowse),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Stickers and other small add-ons not already in the bag. Shop orders
/// average ~1.7 items and these convert best per view, so the bag is where
/// they earn their place. Renders nothing until loaded.
class _AddOns extends ConsumerWidget {
  const _AddOns();

  static const _photoWidth = 84.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addOns = ref.watch(shopAddOnsProvider).value ?? const [];
    if (addOns.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    void open(ShopProduct product) {
      // The sheet sits on the same navigator the product page goes on.
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ProductScreen(
            slug: product.slug,
            product: product,
            source: AnalyticsEventConstants.sourceBagAddOn,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.shopAddOnsTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _photoWidth / kShopPhotoAspect + 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: addOns.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final product = addOns[index];
                final price = product.fromPrice;
                return Semantics(
                  button: true,
                  label: product.name,
                  child: GestureDetector(
                    onTap: () => open(product),
                    child: SizedBox(
                      width: _photoWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: _photoWidth / kShopPhotoAspect,
                            child: HomeGradientBorder(
                              backgroundColor: theme.colorScheme.surface,
                              borderRadius: 12,
                              borderWidth: 0.5,
                              child: ShopPhoto(url: product.leadImage?.url),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onSurface,
                              letterSpacing: 0.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (price != null)
                            Text(
                              price.format(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                letterSpacing: 0.2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
