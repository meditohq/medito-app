import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/shop/shop_models.dart';

/// Read-only client for the Fourthwall Storefront API behind
/// shop.medito.app. Checkout itself stays on Fourthwall's hosted page — we
/// only build the link to it.
///
/// Payloads are heavy (a 12-product page is ~3MB of JSON, mostly repeated
/// image URLs), so responses are decoded and slimmed in a background isolate.
class FourthwallService {
  FourthwallService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _host = 'storefront-api.fourthwall.com';

  /// Storefront tokens are public by design (Fourthwall ships them to
  /// browsers in its own starter kits); they can only read the catalogue.
  static const _storefrontToken = 'ptkn_ef28ed22-a3fe-4c53-b505-121e01ff212e';

  static const shopDomain = 'shop.medito.app';

  /// Fourthwall converts from USD but rejects currencies it can't settle
  /// (e.g. COP) with a 400.
  static const fallbackCurrency = 'USD';

  /// The virtual collection that holds every public product.
  static const allCollection = 'all';

  /// Optional collection, curated in Fourthwall admin, that sets which
  /// products the Home row shows. The first stays featured, the rest rotate
  /// daily. Absent → whole shop. Sales ranking must be supplied by the shop;
  /// the public Storefront API exposes neither sales counts nor sales sorting.
  static const homeCollection = 'app-home';

  /// Cheap add-ons offered in the bag.
  static const addOnCollection = 'stickers';

  static const pageSize = 12;
  static const _timeout = Duration(seconds: 20);

  /// One page of [collection], in the shop's own order.
  Future<ShopProductPage> fetchProductsPage({
    String collection = allCollection,
    required int page,
    required String currency,
  }) async {
    final body = await _get('/v1/collections/$collection/products', {
      'currency': currency,
      'page': '$page',
      'size': '$pageSize',
    });
    return compute(_parseProductPage, body);
  }

  Future<ShopProduct> fetchProduct(
    String slug, {
    required String currency,
  }) async {
    final body = await _get('/v1/products/$slug', {'currency': currency});
    return compute(_parseProduct, body);
  }

  /// The measurement chart from the product's web page (~44KB gzipped),
  /// fetched only when someone opens the size guide. Null if it has none.
  Future<ShopSizeChart?> fetchSizeChart(String slug) async {
    final http.Response response;
    try {
      response = await _client.get(productWebUri(slug)).timeout(_timeout);
    } catch (e) {
      throw NetworkConnectionError(message: 'Size chart for $slug failed: $e');
    }
    if (response.statusCode != 200) return null;
    return compute(parseSizeChartHtml, utf8.decode(response.bodyBytes));
  }

  Future<List<ShopCollection>> fetchCollections() async {
    final body = await _get('/v1/collections', const {});
    final json = jsonDecode(body) as Map<String, dynamic>;
    return [
      for (final c in (json['results'] as List? ?? const []))
        ShopCollection.fromJson((c as Map).cast()),
    ];
  }

  /// Fourthwall's direct checkout link: it builds a fresh cart from the
  /// variant ids and 303s into the hosted checkout, so there's no server
  /// cart for us to keep in sync.
  /// https://docs.fourthwall.com/shop-apis/cart-checkout-endpoint
  static Uri checkoutUri(List<BagItem> items, {required String currency}) {
    return Uri.https(shopDomain, '/cart/checkout', {
      'products': items.map((i) => '${i.variantId}:${i.quantity}').join(','),
      'currency': currency,
      'utm_source': 'medito_app',
      'utm_medium': 'app',
    });
  }

  static Uri productWebUri(String slug) =>
      Uri.https(shopDomain, '/products/$slug');

  Future<String> _get(String path, Map<String, String> query) async {
    final uri = Uri.https(_host, path, {
      ...query,
      'storefront_token': _storefrontToken,
    });
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } catch (e) {
      throw NetworkConnectionError(message: 'Fourthwall $path failed: $e');
    }
    final currency = query['currency'];
    if (response.statusCode == 400 &&
        currency != null &&
        currency != fallbackCurrency) {
      throw UnsupportedCurrencyError(currency);
    }
    if (response.statusCode == 404) throw const NotFoundError();
    if (response.statusCode != 200) {
      throw ServerError(
        message: 'Fourthwall $path returned ${response.statusCode}',
      );
    }
    return utf8.decode(response.bodyBytes);
  }
}

class ShopProductPage {
  const ShopProductPage({required this.products, required this.hasNextPage});

  final List<ShopProduct> products;
  final bool hasNextPage;
}

class UnsupportedCurrencyError implements Exception {
  const UnsupportedCurrencyError(this.currency);

  final String currency;

  @override
  String toString() => 'UnsupportedCurrencyError($currency)';
}

ShopProductPage _parseProductPage(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final paging = (json['paging'] as Map?)?.cast<String, dynamic>();
  return ShopProductPage(
    products: [
      for (final p in (json['results'] as List? ?? const []))
        ShopProduct.fromJson((p as Map).cast()),
    ].where((p) => p.variants.isNotEmpty).toList(),
    hasNextPage: paging?['hasNextPage'] == true,
  );
}

ShopProduct _parseProduct(String body) =>
    ShopProduct.fromJson(jsonDecode(body) as Map<String, dynamic>);
