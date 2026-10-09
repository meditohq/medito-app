import 'package:flutter/material.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/shop/shop_models.dart';
import 'package:medito/views/home/home_styles.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/views/shop/widgets/shop_photo.dart';

/// Product photos are all shot 3:4.
const kShopPhotoAspect = 3 / 4;

/// Height of the name + price block under a grid card's photo.
const kShopCardCaptionHeight = 74.0;

class ShopProductCard extends StatelessWidget {
  const ShopProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  final ShopProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final onSurface = theme.colorScheme.onSurface;
    final price = product.fromPrice;
    final available = product.isAvailable;
    final priceLabel = price == null
        ? ''
        : product.hasVariedPrices
        ? l10n.shopFromPrice(price.format())
        : price.format();

    // The label hides the photo's pill, so carry its state here: a sold-out
    // product sounded the same as an available one.
    final status = !available
        ? ', ${l10n.shopSoldOut}'
        : product.isNewAt(DateTime.now())
        ? ', ${l10n.newProductLabel}'
        : '';

    return Semantics(
      button: true,
      label: '${product.name}, $priceLabel$status',
      excludeSemantics: true,
      // excludeSemantics drops the child's tap action, so give it here.
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: kShopPhotoAspect,
              child: HomeGradientBorder(
                backgroundColor: theme.cardColor,
                borderRadius: kHomeTileRadius,
                borderWidth: 0.5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: available ? 1 : 0.45,
                      child: ShopPhoto(url: product.leadImage?.url),
                    ),
                    if (!available)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: ShopPill(label: l10n.shopSoldOut),
                      )
                    else if (product.isNewAt(DateTime.now()))
                      Positioned(
                        left: 8,
                        top: 8,
                        child: ShopPill(label: l10n.newProductLabel),
                      ),
                    Positioned.fill(
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(onTap: onTap),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: kShopCardCaptionHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      priceLabel,
                      maxLines: 1,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded label over a photo ("NEW", "Sold out").
class ShopPill extends StatelessWidget {
  const ShopPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
