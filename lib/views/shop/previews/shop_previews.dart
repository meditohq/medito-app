// Widget previews for the native shop.
//
// Run from the project root:
//
//   flutter widget-preview start --web-server
//
// The real screens render against a fake FourthwallService serving
// [shopPreviewProductsJson], so only product photos touch the network.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:medito/constants/constants.dart';
import 'package:medito/models/shop/shop_models.dart';
import 'package:medito/providers/shop/shop_providers.dart';
import 'package:medito/services/shop/fourthwall_service.dart';
import 'package:medito/views/previews/preview_support.dart';
import 'package:medito/views/shop/bag_sheet.dart';
import 'package:medito/views/shop/product_screen.dart';
import 'package:medito/views/shop/shop_navigation.dart';
import 'package:medito/views/shop/shop_screen.dart';

import 'shop_preview_fixtures.dart';

final previewShopProducts = [
  for (final p in jsonDecode(shopPreviewProductsJson) as List)
    ShopProduct.fromJson((p as Map).cast()),
];

ShopProduct _product(String slug) =>
    previewShopProducts.firstWhere((p) => p.slug == slug);

/// Serves the fixture instead of calling Fourthwall. [hang] keeps every
/// request pending to show loading states.
class PreviewFourthwallService extends FourthwallService {
  PreviewFourthwallService({this.hang = false});

  final bool hang;

  Future<T> _serve<T>(T value) =>
      hang ? Completer<T>().future : Future.value(value);

  @override
  Future<ShopProductPage> fetchProductsPage({
    String collection = FourthwallService.allCollection,
    required int page,
    required String currency,
  }) => _serve(
    ShopProductPage(products: previewShopProducts, hasNextPage: false),
  );

  @override
  Future<ShopProduct> fetchProduct(String slug, {required String currency}) =>
      _serve(_product(slug));

  @override
  Future<ShopSizeChart?> fetchSizeChart(String slug) => _serve(
    ShopSizeChart(
      measures: const ['Length', 'Width', 'SleeveLength'],
      rows: [
        for (final (i, size) in ['S', 'M', 'L', 'XL', '2XL'].indexed)
          ShopSizeRow(
            label: size,
            values: {
              'Length': (inches: 28.0 + i, cm: 71.1 + i * 2.5),
              'Width': (inches: 18.0 + i * 2, cm: 45.7 + i * 5.1),
              'SleeveLength': (inches: 8.0 + i * 0.5, cm: 20.3 + i * 1.3),
            },
          ),
      ],
    ),
  );

  @override
  Future<List<ShopCollection>> fetchCollections() => _serve(const [
    ShopCollection(id: '1', slug: 't-shirts', name: 'Art T-Shirts'),
    ShopCollection(id: '2', slug: 'prints', name: 'Prints'),
    ShopCollection(id: '3', slug: 'stickers', name: 'Stickers'),
    ShopCollection(id: '4', slug: 'candles', name: 'Candles'),
  ]);
}

List<Override> _shopOverrides({bool hang = false}) => [
  fourthwallServiceProvider.overrideWithValue(
    PreviewFourthwallService(hang: hang),
  ),
];

/// Bag seeded with a shirt, a mug and a print.
Map<String, Object> _bagPrefs(
  Map<String, Object> base, {
  bool checkedOut = false,
}) {
  final shirt = _product('sleepy-cat-t-shirt');
  final mug = _product('sleepy-cat-mug');
  final print = _product('medito-boat-print');
  final items = [
    _line(shirt, shirt.variantFor(color: 'Lilac', size: 'M')!, 1),
    _line(mug, mug.variants.first, 2),
    _line(print, print.variants.first, 1),
  ];
  return {
    ...base,
    SharedPreferenceConstants.shopBag: jsonEncode([
      for (final i in items) i.toJson(),
    ]),
    SharedPreferenceConstants.shopBagCheckoutStarted: checkedOut,
  };
}

BagItem _line(ShopProduct p, ShopVariant v, int quantity) => BagItem(
  variantId: v.id,
  productSlug: p.slug,
  productName: p.name,
  variantLabel: v.label,
  unitPrice: v.price,
  quantity: quantity,
  imageUrl: p.imagesFor(v).first.url,
);

Widget wrapShopDark(Widget child) =>
    PreviewShell(prefs: prefsDark, overrides: _shopOverrides(), child: child);

Widget wrapShopLight(Widget child) => PreviewShell(
  prefs: prefsLight,
  themeMode: ThemeMode.light,
  overrides: _shopOverrides(),
  child: child,
);

Widget wrapShopDarkWithBag(Widget child) => PreviewShell(
  prefs: _bagPrefs(prefsDark),
  overrides: _shopOverrides(),
  child: child,
);

Widget wrapShopLoading(Widget child) => PreviewShell(
  prefs: prefsDark,
  overrides: _shopOverrides(hang: true),
  child: child,
);

/// The bag sheet as it sits over a page.
Widget _sheetOver(Map<String, Object> prefs, ThemeMode mode) => PreviewShell(
  prefs: prefs,
  themeMode: mode,
  overrides: _shopOverrides(),
  child: Builder(
    builder: (context) => Scaffold(
      backgroundColor: Colors.black54,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Theme.of(context).bottomSheetTheme.backgroundColor,
          shape: Theme.of(context).bottomSheetTheme.shape,
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: ShopBagSheet(onBrowse: () {}),
          ),
        ),
      ),
    ),
  ),
);

@Preview(
  group: 'Shop',
  name: 'Grid · dark',
  size: phoneSize,
  wrapper: wrapShopDarkWithBag,
)
Widget shopGridDark() => const ShopScreen(source: 'preview');

@Preview(
  group: 'Shop',
  name: 'Grid · light',
  size: phoneSize,
  wrapper: wrapShopLight,
)
Widget shopGridLight() => const ShopScreen(source: 'preview');

@Preview(
  group: 'Shop',
  name: 'Grid · loading',
  size: phoneSize,
  wrapper: wrapShopLoading,
)
Widget shopGridLoading() => const ShopScreen(source: 'preview');

@Preview(
  group: 'Shop',
  name: 'Grid · tablet',
  size: Size(1024, 768),
  wrapper: wrapShopDark,
)
Widget shopGridTablet() => const ShopScreen(source: 'preview');

@Preview(
  group: 'Shop',
  name: 'T-shirt · dark',
  size: phoneSize,
  wrapper: wrapShopDarkWithBag,
)
Widget shopProductShirtDark() => ProductScreen(
  slug: 'sleepy-cat-t-shirt',
  source: 'preview',
  product: _product('sleepy-cat-t-shirt'),
);

@Preview(
  group: 'Shop',
  name: 'T-shirt · light',
  size: phoneSize,
  wrapper: wrapShopLight,
)
Widget shopProductShirtLight() => ProductScreen(
  slug: 'sleepy-cat-t-shirt',
  source: 'preview',
  product: _product('sleepy-cat-t-shirt'),
);

@Preview(
  group: 'Shop',
  name: 'Gift card',
  size: phoneSize,
  wrapper: wrapShopDark,
)
Widget shopProductGiftCard() => ProductScreen(
  slug: 'medito-gift-card',
  source: 'preview',
  product: _product('medito-gift-card'),
);

@Preview(
  group: 'Shop',
  name: 'Product · loading from home',
  size: phoneSize,
  wrapper: wrapShopLoading,
)
Widget shopProductLoading() => const ShopProductLoadingPreview();

@Preview(
  group: 'Shop',
  name: 'Product · tablet',
  size: Size(1024, 768),
  wrapper: wrapShopDark,
)
Widget shopProductTablet() => ProductScreen(
  slug: 'sleepy-cat-t-shirt',
  source: 'preview',
  product: _product('sleepy-cat-t-shirt'),
);

@Preview(group: 'Shop', name: 'Bag · dark', size: phoneSize)
Widget shopBagDark() => _sheetOver(_bagPrefs(prefsDark), ThemeMode.dark);

@Preview(
  group: 'Shop',
  name: 'Bag · light, back from checkout',
  size: phoneSize,
)
Widget shopBagLight() =>
    _sheetOver(_bagPrefs(prefsLight, checkedOut: true), ThemeMode.light);

@Preview(group: 'Shop', name: 'Bag · empty', size: phoneSize)
Widget shopBagEmpty() => _sheetOver(prefsDark, ThemeMode.dark);

/// Opened from a home tile: only the name and photo are known.
class ShopProductLoadingPreview extends StatelessWidget {
  const ShopProductLoadingPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final shirt = _product('sleepy-cat-t-shirt');
    return ProductScreen(
      slug: shirt.slug,
      source: 'preview',
      preview: ShopProductPreview(
        name: shirt.name,
        imageUrl: shirt.leadImage?.url,
      ),
    );
  }
}
