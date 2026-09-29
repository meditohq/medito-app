import 'dart:convert';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/shop/shop_models.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/services/shop/fourthwall_service.dart';
import 'package:medito/utils/logger.dart';

final fourthwallServiceProvider = Provider<FourthwallService>(
  (ref) => FourthwallService(),
);

/// Riverpod 3 retries failed providers by default; the shop shows its own
/// retry button instead of spinning through backoff.
Duration? _noRetry(int _, Object _) => null;

/// Currency the shop prices in: the device region's, until Fourthwall
/// rejects it, then USD for the rest of the session.
final shopCurrencyProvider = NotifierProvider<ShopCurrencyNotifier, String>(
  ShopCurrencyNotifier.new,
);

class ShopCurrencyNotifier extends Notifier<String> {
  @override
  String build() => deviceCurrency(PlatformDispatcher.instance.locale);

  void fallBack() => state = FourthwallService.fallbackCurrency;
}

String deviceCurrency(Locale locale) {
  try {
    return NumberFormat.simpleCurrency(
          locale: locale.toString(),
        ).currencyName ??
        FourthwallService.fallbackCurrency;
  } catch (_) {
    return FourthwallService.fallbackCurrency;
  }
}

/// Runs [fetch] in the shop currency, dropping to USD once if Fourthwall
/// can't price in the device's.
Future<T> _inShopCurrency<T>(
  Ref ref,
  Future<T> Function(String currency) fetch,
) async {
  try {
    return await fetch(ref.read(shopCurrencyProvider));
  } on UnsupportedCurrencyError catch (e) {
    AppLogger.w('SHOP', '${e.currency} not supported, falling back to USD');
    ref.read(shopCurrencyProvider.notifier).fallBack();
    return fetch(FourthwallService.fallbackCurrency);
  }
}

final shopCollectionsProvider = FutureProvider<List<ShopCollection>>(
  (ref) => ref.watch(fourthwallServiceProvider).fetchCollections(),
  retry: _noRetry,
);

/// A single product, for pages opened by slug (home tile, deeplink).
final shopProductProvider = FutureProvider.family<ShopProduct, String>(
  (ref, slug) => _inShopCurrency(
    ref,
    (currency) => ref
        .watch(fourthwallServiceProvider)
        .fetchProduct(slug, currency: currency),
  ),
  retry: _noRetry,
);

/// A product's size chart, loaded when the size guide is opened.
final shopSizeChartProvider = FutureProvider.family<ShopSizeChart?, String>(
  (ref, slug) => ref.watch(fourthwallServiceProvider).fetchSizeChart(slug),
  retry: _noRetry,
);

class ShopListing {
  const ShopListing({
    required this.products,
    required this.hasNextPage,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<ShopProduct> products;
  final bool hasNextPage;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  ShopListing copyWith({
    List<ShopProduct>? products,
    bool? hasNextPage,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) => ShopListing(
    products: products ?? this.products,
    hasNextPage: hasNextPage ?? this.hasNextPage,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

/// Products in a collection, a page at a time. Keyed by collection slug
/// ([FourthwallService.allCollection] for everything).
final shopListingProvider =
    AsyncNotifierProvider.family<ShopListingNotifier, ShopListing, String>(
      ShopListingNotifier.new,
      retry: _noRetry,
    );

class ShopListingNotifier extends AsyncNotifier<ShopListing> {
  ShopListingNotifier(this.collection);

  final String collection;
  int _nextPage = 0;

  Future<ShopProductPage> _fetch(int page) => _inShopCurrency(
    ref,
    (currency) => ref
        .read(fourthwallServiceProvider)
        .fetchProductsPage(
          collection: collection,
          page: page,
          currency: currency,
        ),
  );

  @override
  Future<ShopListing> build() async {
    _nextPage = 0;
    final page = await _fetch(0);
    _nextPage = 1;
    return ShopListing(products: page.products, hasNextPage: page.hasNextPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNextPage || current.isLoadingMore) {
      return;
    }
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await _fetch(_nextPage);
      // A refresh while this page was in flight replaced the listing.
      if (state.value?.isLoadingMore != true) return;
      _nextPage++;
      state = AsyncData(
        current.copyWith(
          products: [...current.products, ...page.products],
          hasNextPage: page.hasNextPage,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      AppLogger.w('SHOP', 'Loading page $_nextPage of $collection failed: $e');
      if (state.value?.isLoadingMore != true) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreFailed: true),
      );
    }
  }
}

/// The Home row. If the shop has an [FourthwallService.homeCollection]
/// collection it's used as curated, in its admin order; otherwise the first
/// page of the whole shop (shared with the grid, so either opens instantly
/// after the other), shuffled daily by the caller. In stock only.
final homeShopProductsProvider = FutureProvider<HomeShopProducts>((ref) async {
  List<ShopProduct> inStock(ShopListing l) =>
      l.products.where((p) => p.isAvailable).toList();
  try {
    final curated = inStock(
      await ref.watch(
        shopListingProvider(FourthwallService.homeCollection).future,
      ),
    );
    if (curated.isNotEmpty) {
      return HomeShopProducts(products: curated, curated: true);
    }
  } on NotFoundError {
    // No curated collection; fall through to the whole shop.
  }
  final all = await ref.watch(
    shopListingProvider(FourthwallService.allCollection).future,
  );
  return HomeShopProducts(products: inStock(all), curated: false);
}, retry: _noRetry);

class HomeShopProducts {
  const HomeShopProducts({required this.products, required this.curated});

  final List<ShopProduct> products;

  /// Ordered by hand in Fourthwall admin; keep that order.
  final bool curated;
}

/// Add-ons for the bag: in-stock products from
/// [FourthwallService.addOnCollection] that aren't in the bag yet.
final shopAddOnsProvider = FutureProvider<List<ShopProduct>>((ref) async {
  final listing = await ref.watch(
    shopListingProvider(FourthwallService.addOnCollection).future,
  );
  final inBag = ref.watch(
    shopBagProvider.select((b) => b.items.map((i) => i.productSlug).toSet()),
  );
  return listing.products
      .where((p) => p.isAvailable && !inBag.contains(p.slug))
      .toList();
}, retry: _noRetry);

class ShopBag {
  const ShopBag({this.items = const [], this.checkoutStarted = false});

  final List<BagItem> items;

  /// The user left for checkout with these items and hasn't changed the bag
  /// since, so it may already be ordered.
  final bool checkoutStarted;

  bool get isEmpty => items.isEmpty;

  int get quantity => items.fold(0, (sum, i) => sum + i.quantity);

  /// Null for an empty bag. Items are priced in the shop currency at the time
  /// they were added; checkout reprices everything anyway.
  ShopMoney? get subtotal {
    if (items.isEmpty) return null;
    final currency = items.first.unitPrice.currency;
    return ShopMoney(
      value: items
          .where((i) => i.unitPrice.currency == currency)
          .fold(0.0, (sum, i) => sum + i.total.value),
      currency: currency,
    );
  }
}

final shopBagProvider = NotifierProvider<ShopBagNotifier, ShopBag>(
  ShopBagNotifier.new,
);

class ShopBagNotifier extends Notifier<ShopBag> {
  static const maxQuantity = 10;

  @override
  ShopBag build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(SharedPreferenceConstants.shopBag);
    var items = <BagItem>[];
    if (raw != null) {
      try {
        items = [
          for (final i in jsonDecode(raw) as List)
            BagItem.fromJson((i as Map).cast()),
        ];
      } catch (e) {
        AppLogger.w('SHOP', 'Dropping unreadable bag: $e');
      }
    }
    return ShopBag(
      items: items,
      checkoutStarted:
          items.isNotEmpty &&
          (prefs.getBool(SharedPreferenceConstants.shopBagCheckoutStarted) ??
              false),
    );
  }

  void add(ShopProduct product, ShopVariant variant, {int quantity = 1}) {
    final items = [...state.items];
    final index = items.indexWhere((i) => i.variantId == variant.id);
    if (index >= 0) {
      final existing = items[index];
      items[index] = existing.copyWith(
        quantity: (existing.quantity + quantity).clamp(1, maxQuantity),
        unitPrice: variant.price,
      );
    } else {
      final image = product.imagesFor(variant).firstOrNull ?? product.leadImage;
      items.add(
        BagItem(
          variantId: variant.id,
          productSlug: product.slug,
          productName: product.name,
          variantLabel: product.variants.length > 1 ? variant.label : '',
          unitPrice: variant.price,
          quantity: quantity.clamp(1, maxQuantity),
          imageUrl: image?.url,
        ),
      );
    }
    _save(ShopBag(items: items));
  }

  /// Zero removes the line.
  void setQuantity(String variantId, int quantity) {
    final items = [
      for (final i in state.items)
        if (i.variantId != variantId)
          i
        else if (quantity > 0)
          i.copyWith(quantity: quantity.clamp(1, maxQuantity)),
    ];
    _save(ShopBag(items: items));
  }

  void remove(String variantId) => setQuantity(variantId, 0);

  void clear() => _save(const ShopBag());

  void markCheckoutStarted() {
    if (state.isEmpty) return;
    _save(ShopBag(items: state.items, checkoutStarted: true));
  }

  void _save(ShopBag bag) {
    state = bag;
    final prefs = ref.read(sharedPreferencesProvider);
    if (bag.isEmpty) {
      prefs.remove(SharedPreferenceConstants.shopBag);
      prefs.remove(SharedPreferenceConstants.shopBagCheckoutStarted);
      return;
    }
    prefs.setString(
      SharedPreferenceConstants.shopBag,
      jsonEncode([for (final i in bag.items) i.toJson()]),
    );
    prefs.setBool(
      SharedPreferenceConstants.shopBagCheckoutStarted,
      bag.checkoutStarted,
    );
  }
}
