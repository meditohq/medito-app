import 'package:medito/widgets/inputs/medito_segmented_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/shop/shop_models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/shop/shop_providers.dart';
import 'package:medito/views/home/home_styles.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/views/shop/bag_sheet.dart';
import 'package:medito/views/shop/shop_navigation.dart';
import 'package:medito/views/shop/shop_screen.dart';
import 'package:medito/views/shop/widgets/shop_error_view.dart';
import 'package:medito/views/shop/widgets/shop_photo.dart';
import 'package:medito/views/shop/widgets/shop_product_card.dart';
import 'package:medito/widgets/adaptive/adaptive_page_body.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/shimmers/widgets/box_shimmer_widget.dart';

/// A single product: photos for the chosen colour, colour/size pickers,
/// details, and a sticky "Add to bag".
///
/// Opened either with the full [product] (from the shop grid) or just a
/// [slug] plus an optional [preview] (home tile, deeplink), in which case
/// the record is fetched and the preview paints meanwhile.
class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({
    super.key,
    required this.slug,
    required this.source,
    this.product,
    this.preview,
  });

  final String slug;
  final String source;
  final ShopProduct? product;
  final ShopProductPreview? preview;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  String? _color;
  String? _size;
  String? _optionId;
  bool _justAdded = false;
  String? _initialisedFor;

  static const _wideBreakpoint = 720.0;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    final price = product?.fromPrice;
    final name = product?.name ?? widget.preview?.name;
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: AnalyticsEventConstants.shopProductViewed,
          parameters: {
            'product_slug': widget.slug,
            'source': widget.source,
            'product_name': ?name,
            if (price != null) 'value': price.value,
            if (price != null) 'currency': price.currency,
          },
        );
  }

  /// Default choices once the product is known: first colour in stock, the
  /// only size if there's just one (otherwise the user must pick), first
  /// option for label-picked products.
  void _initSelection(ShopProduct product) {
    if (_initialisedFor == product.id) return;
    _initialisedFor = product.id;
    final colors = product.colors;
    _color = colors
        .map((c) => c.name)
        .firstWhere(
          (c) => product.variants.any((v) => v.color?.name == c && v.inStock),
          orElse: () => colors.firstOrNull?.name ?? '',
        );
    if (_color!.isEmpty) _color = null;
    final sizes = product.sizes;
    _size = sizes.length == 1 ? sizes.first : null;
    _optionId = product.pickByLabel
        ? (product.variants.firstWhere(
            (v) => v.inStock,
            orElse: () => product.variants.first,
          )).id
        : null;
  }

  /// The exact variant chosen, or null while a size is still to pick.
  ShopVariant? _selectedVariant(ShopProduct product) {
    if (product.pickByLabel) {
      return product.variants.where((v) => v.id == _optionId).firstOrNull;
    }
    if (product.sizes.isNotEmpty && _size == null) return null;
    return product.variantFor(color: _color, size: _size);
  }

  /// What the gallery and price show: the chosen variant, or the chosen
  /// colour's first variant before a size is picked.
  ShopVariant? _displayVariant(ShopProduct product) =>
      _selectedVariant(product) ??
      product.variantFor(color: _color) ??
      product.variants.firstOrNull;

  void _selectColor(ShopProduct product, String color) {
    setState(() {
      _color = color;
      final stillAvailable =
          _size != null &&
          (product.variantFor(color: color, size: _size)?.inStock ?? false);
      if (!stillAvailable && product.sizes.length > 1) _size = null;
    });
  }

  void _addToBag(ShopProduct product, ShopVariant variant) {
    HapticFeedback.lightImpact();
    ref.read(shopBagProvider.notifier).add(product, variant);
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: AnalyticsEventConstants.shopAddToBag,
          parameters: {
            'product_slug': product.slug,
            'variant_id': variant.id,
            'quantity': 1,
            'value': variant.price.value,
            'currency': variant.price.currency,
          },
        );
    setState(() => _justAdded = true);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _justAdded = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final product =
        widget.product ?? ref.watch(shopProductProvider(widget.slug)).value;
    final error = widget.product == null
        ? ref.watch(shopProductProvider(widget.slug)).error
        : null;
    if (product != null) _initSelection(product);

    final display = product == null ? null : _displayVariant(product);
    final images = product == null ? <ShopImage>[] : product.imagesFor(display);
    final galleryUrls = images.isNotEmpty
        ? images.map((i) => i.url).toList()
        : [if (widget.preview?.imageUrl != null) widget.preview!.imageUrl!];

    Widget body;
    if (product == null && error != null) {
      body = Center(
        child: ShopErrorView(
          surface: 'product',
          error: error,
          productSlug: widget.slug,
          onRetry: () => ref.invalidate(shopProductProvider(widget.slug)),
        ),
      );
    } else {
      final gallery = _Gallery(
        key: ValueKey(display?.color?.name ?? display?.id),
        urls: galleryUrls,
      );
      final details = _Details(
        name: product?.name ?? widget.preview?.name ?? '',
        product: product,
        display: display,
        color: _color,
        size: _size,
        optionId: _optionId,
        onColor: (c) => _selectColor(product!, c),
        onSize: (s) => setState(() => _size = s),
        onOption: (id) => setState(() => _optionId = id),
      );
      body = LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _wideBreakpoint) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(kHomeCardRadius),
                      child: gallery,
                    ),
                  ),
                ),
                Expanded(child: SingleChildScrollView(child: details)),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [gallery, details],
            ),
          );
        },
      );
    }

    return Scaffold(
      bottomNavigationBar: _ActionBar(
        product: product,
        variant: product == null ? null : _selectedVariant(product),
        needsSize: product != null && product.sizes.isNotEmpty && _size == null,
        justAdded: _justAdded,
        onAdd: _addToBag,
        // From the grid the shop is right underneath; elsewhere open it.
        onBrowse: widget.source == AnalyticsEventConstants.sourceShopGrid
            ? () => Navigator.of(context).pop()
            : () => openShop(context, source: widget.source),
      ),
      body: AdaptivePageBody(
        maxWidth: 1100,
        child: SafeArea(bottom: false, child: body),
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({super.key, required this.urls});

  final List<String> urls;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urls = widget.urls;

    return AspectRatio(
      aspectRatio: kShopPhotoAspect,
      child: ColoredBox(
        color: theme.cardColor,
        child: Stack(
          children: [
            if (urls.isEmpty)
              const Positioned.fill(child: BoxShimmerWidget())
            else
              PageView.builder(
                itemCount: urls.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => ShopPhoto(url: urls[i]),
              ),
            if (urls.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: _PageDots(count: urls.length, index: _page),
              ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: i == index ? 1 : 0.55,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.name,
    required this.product,
    required this.display,
    required this.color,
    required this.size,
    required this.optionId,
    required this.onColor,
    required this.onSize,
    required this.onOption,
  });

  final String name;
  final ShopProduct? product;
  final ShopVariant? display;
  final String? color;
  final String? size;
  final String? optionId;
  final ValueChanged<String> onColor;
  final ValueChanged<String> onSize;
  final ValueChanged<String> onOption;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);
    final product = this.product;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: onSurface,
              fontSize: 24,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          if (product == null)
            const BoxShimmerWidget(width: 72, height: 20, borderRadius: 6)
          else
            _Price(
              product: product,
              display: display,
              sizeChosen: size != null,
            ),
          if (product != null) ...[
            if (product.colors.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionLabel(label: l10n.shopColour, value: color),
              const SizedBox(height: 12),
              _ColorSwatches(
                product: product,
                selected: color,
                onSelected: onColor,
              ),
            ],
            if (product.sizes.length > 1) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SectionLabel(label: l10n.shopSize, value: size),
                  ),
                  if (product.hasApparelSizes)
                    TextButton.icon(
                      onPressed: () => _showSizeGuide(context, product, size),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.straighten_rounded, size: 18),
                      label: Text(l10n.shopSizeGuide),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in product.sizes)
                    ShopChoicePill(
                      label: s,
                      minWidth: 56,
                      selected: s == size,
                      enabled:
                          product.variantFor(color: color, size: s)?.inStock ??
                          false,
                      onTap: () => onSize(s),
                    ),
                ],
              ),
            ],
            if (product.pickByLabel) ...[
              const SizedBox(height: 24),
              _SectionLabel(label: l10n.shopOption),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in product.variants)
                    ShopChoicePill(
                      label: v.label,
                      selected: v.id == optionId,
                      enabled: v.inStock,
                      onTap: () => onOption(v.id),
                    ),
                ],
              ),
            ],
            if (product.descriptionHtml.isNotEmpty) ...[
              const SizedBox(height: 28),
              _HtmlBlocks(html: product.descriptionHtml, color: muted),
            ],
            if (product.infoSections.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final section in product.infoSections)
                _InfoSection(section: section),
            ],
            const SizedBox(height: 24),
            _SupportNote(text: l10n.shopSupportNote),
          ],
        ],
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({
    required this.product,
    required this.display,
    required this.sizeChosen,
  });

  final ShopProduct product;
  final ShopVariant? display;
  final bool sizeChosen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final style = theme.textTheme.titleLarge?.copyWith(
      color: onSurface,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    );

    // Before a size is picked, show the colour's cheapest size as "From".
    final needsSize = product.sizes.length > 1 && !sizeChosen;
    final colorVariants = product.variants.where(
      (v) => display?.color == null || v.color?.name == display!.color!.name,
    );
    final cheapest = colorVariants.isEmpty
        ? product.fromPrice
        : colorVariants
              .map((v) => v.price)
              .reduce((a, b) => a.value <= b.value ? a : b);
    final varied = colorVariants.map((v) => v.price.value).toSet().length > 1;

    final price = needsSize ? cheapest : display?.price;
    if (price == null) return const SizedBox.shrink();
    final compareAt = needsSize ? null : display?.compareAtPrice;
    final shownPrice = needsSize && varied
        ? l10n.shopFromPrice(price.format())
        : price.format();
    final onSale = compareAt != null && compareAt.value > price.value;

    // Two bare prices ("$30 $40") gave no hint which was the old one.
    final priceSemantics = onSale
        ? l10n.shopPriceWas(shownPrice, compareAt.format())
        : shownPrice;
    return Semantics(
      label: product.isAvailable
          ? priceSemantics
          : '$priceSemantics, ${l10n.shopSoldOut}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(shownPrice, style: style),
          if (onSale) ...[
            const SizedBox(width: 8),
            Text(
              compareAt.format(),
              style: style?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: onSurface.withValues(alpha: 0.5),
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
          if (!product.isAvailable) ...[
            const SizedBox(width: 12),
            ShopPill(label: l10n.shopSoldOut),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (value != null)
            TextSpan(
              text: '  ·  $value',
              style: TextStyle(color: onSurface.withValues(alpha: 0.6)),
            ),
        ],
      ),
      style: theme.textTheme.titleSmall?.copyWith(color: onSurface),
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({
    required this.product,
    required this.selected,
    required this.onSelected,
  });

  final ShopProduct product;
  final String? selected;
  final ValueChanged<String> onSelected;

  static const _size = 36.0;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final scaffold = Theme.of(context).scaffoldBackgroundColor;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in product.colors)
          Builder(
            builder: (context) {
              final isSelected = c.name == selected;
              final inStock = product.variants.any(
                (v) => v.color?.name == c.name && v.inStock,
              );
              final fill =
                  _parseHex(c.swatch) ?? onSurface.withValues(alpha: 0.2);
              return Semantics(
                label: c.name,
                selected: isSelected,
                enabled: inStock,
                button: true,
                child: Tooltip(
                  message: c.name,
                  // The Semantics above already names it ("Black, Black").
                  excludeFromSemantics: true,
                  child: GestureDetector(
                    onTap: () => onSelected(c.name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _size + 8,
                      height: _size + 8,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? onSurface : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: fill,
                          border: Border.all(
                            color: Color.lerp(
                              fill,
                              onSurface,
                              0.25,
                            )!.withValues(alpha: 0.5),
                            width: 0.5,
                          ),
                        ),
                        child: inStock
                            ? null
                            : CustomPaint(painter: _StrikePainter(scaffold)),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}

/// Diagonal slash over an out-of-stock swatch.
class _StrikePainter extends CustomPainter {
  _StrikePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter old) => old.color != color;
}

class _HtmlBlocks extends StatelessWidget {
  const _HtmlBlocks({required this.html, required this.color});

  final String html;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(color: color, fontSize: 15, height: 1.55);
    final blocks = parseShopHtml(html);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, block) in blocks.indexed)
          Padding(
            padding: EdgeInsets.only(
              top: i == 0 ? 0 : (block.isBullet ? 4 : 10),
            ),
            child: block.isBullet
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: style),
                      Expanded(child: Text(block.text, style: style)),
                    ],
                  )
                : Text(block.text, style: style),
          ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.section});

  final ShopInfoSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Column(
        children: [
          Divider(height: 1, color: onSurface.withValues(alpha: 0.1)),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 16),
            iconColor: onSurface,
            collapsedIconColor: onSurface.withValues(alpha: 0.6),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text(
              section.title.isEmpty ? l10n.shopMoreDetails : section.title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            children: [
              _HtmlBlocks(
                html: section.bodyHtml,
                color: onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportNote extends StatelessWidget {
  const _SupportNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return HomeGradientBorder(
      backgroundColor: theme.cardColor,
      borderRadius: kHomeTileRadius,
      borderWidth: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MeditoIcon(
              assetName: MeditoIcons.heart,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.product,
    required this.variant,
    required this.needsSize,
    required this.justAdded,
    required this.onAdd,
    required this.onBrowse,
  });

  final VoidCallback onBrowse;
  final ShopProduct? product;
  final ShopVariant? variant;
  final bool needsSize;
  final bool justAdded;
  final void Function(ShopProduct, ShopVariant) onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final product = this.product;
    final variant = this.variant;

    final soldOut =
        product != null &&
        (!product.isAvailable || (variant != null && !variant.inStock));
    final canAdd = product != null && variant != null && !soldOut;

    final String label;
    if (justAdded) {
      label = l10n.shopAddedToBag;
    } else if (soldOut) {
      label = l10n.shopSoldOut;
    } else if (needsSize) {
      label = l10n.shopSelectSize;
    } else {
      label = variant == null
          ? l10n.shopAddToBag
          : '${l10n.shopAddToBag}  ·  ${variant.price.format()}';
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
              const SizedBox(width: 4),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: canAdd && !justAdded
                        ? () => onAdd(product, variant)
                        : null,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor: justAdded
                          ? theme.elevatedButtonTheme.style?.backgroundColor
                                ?.resolve({})
                          : null,
                      disabledForegroundColor: justAdded
                          ? theme.elevatedButtonTheme.style?.foregroundColor
                                ?.resolve({})
                          : null,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Row(
                        key: ValueKey(label),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (justAdded) ...[
                            const Icon(Icons.check_rounded, size: 20),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(label, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ShopBagButton(
                source: AnalyticsEventConstants.sourceProductPage,
                onBrowse: onBrowse,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fit is the likeliest reason apparel is the most viewed and least bought
/// category in the shop, so the chart sits right by the size picker.
Future<void> _showSizeGuide(
  BuildContext context,
  ShopProduct product,
  String? selectedSize,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
    builder: (_) => _SizeGuideSheet(product: product, selected: selectedSize),
  );
}

class _SizeGuideSheet extends ConsumerStatefulWidget {
  const _SizeGuideSheet({required this.product, this.selected});

  final ShopProduct product;
  final String? selected;

  @override
  ConsumerState<_SizeGuideSheet> createState() => _SizeGuideSheetState();
}

class _SizeGuideSheetState extends ConsumerState<_SizeGuideSheet> {
  /// Inches where people think in inches; centimetres everywhere else.
  late bool _inches = const {
    'US',
    'LR',
    'MM',
  }.contains(WidgetsBinding.instance.platformDispatcher.locale.countryCode);

  String _measureLabel(AppLocalizations l10n, String key) => switch (key) {
    'Length' => l10n.shopMeasureLength,
    'Width' => l10n.shopMeasureWidth,
    'SleeveLength' => l10n.shopMeasureSleeve,
    // Unknown keys from the supplier: "ChestWidth" → "Chest width".
    _ =>
      key
          .replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => ' ${m[1]}')
          .toLowerCase()
          .replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase()),
  };

  String _value(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);
    final chart = ref.watch(shopSizeChartProvider(widget.product.slug));

    Widget body;
    if (chart.isLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (chart.value == null) {
      // No chart (or the page changed shape): the web page still has one.
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: OutlinedButton(
            onPressed: () => openShopInBrowser(slug: widget.product.slug),
            child: Text(l10n.shopOpenInBrowser),
          ),
        ),
      );
    } else {
      final data = chart.value!;
      final headerStyle = theme.textTheme.titleSmall?.copyWith(
        color: muted,
        fontWeight: FontWeight.w600,
      );
      final cellStyle = theme.textTheme.titleSmall?.copyWith(color: onSurface);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 140,
              child: MeditoSegmentedTabs(
                labels: [l10n.shopCentimetres, l10n.shopInches],
                selectedIndex: _inches ? 1 : 0,
                onChanged: (i) => setState(() => _inches = i == 1),
                height: 40,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {0: FlexColumnWidth(0.8)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  _cell(l10n.shopSize, headerStyle),
                  for (final m in data.measures)
                    _cell(_measureLabel(l10n, m), headerStyle),
                ],
              ),
              for (final row in data.rows)
                TableRow(
                  decoration: row.label == widget.selected
                      ? BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  children: [
                    _cell(
                      row.label,
                      cellStyle?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    for (final m in data.measures)
                      _cell(
                        row.values[m] == null
                            ? '–'
                            : _value(
                                _inches
                                    ? row.values[m]!.inches
                                    : row.values[m]!.cm,
                              ),
                        cellStyle,
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.shopSizeChartNote,
            style: theme.textTheme.titleMedium?.copyWith(color: muted),
          ),
        ],
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shopSizeGuide,
              style: theme.textTheme.headlineSmall?.copyWith(color: onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              widget.product.name,
              style: theme.textTheme.titleMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            body,
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, TextStyle? style) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    child: Text(text, style: style),
  );
}
