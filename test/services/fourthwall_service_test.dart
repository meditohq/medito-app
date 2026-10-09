import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/shop/shop_models.dart';
import 'package:medito/services/shop/fourthwall_service.dart';

void main() {
  final fixture = File(
    'test/fixtures/fourthwall_products_page.json',
  ).readAsStringSync();

  test(
    'fetches a page of a collection with token, currency and paging',
    () async {
      late Uri requested;
      final service = FourthwallService(
        client: MockClient((request) async {
          requested = request.url;
          return http.Response.bytes(utf8.encode(fixture), 200);
        }),
      );

      final page = await service.fetchProductsPage(page: 2, currency: 'EUR');

      expect(requested.host, 'storefront-api.fourthwall.com');
      expect(requested.path, '/v1/collections/all/products');
      expect(requested.queryParameters['currency'], 'EUR');
      expect(requested.queryParameters['page'], '2');
      expect(
        requested.queryParameters['size'],
        '${FourthwallService.pageSize}',
      );
      expect(
        requested.queryParameters['storefront_token'],
        startsWith('ptkn_'),
      );
      expect(page.products.map((p) => p.slug), [
        'sleepy-cat-t-shirt',
        'sleepy-cat-mug',
        'medito-gift-card',
      ]);
      expect(page.hasNextPage, isTrue);
    },
  );

  test('a 400 for a non-USD currency is reported as unsupported', () async {
    final service = FourthwallService(
      client: MockClient((_) async => http.Response('{}', 400)),
    );
    expect(
      service.fetchProductsPage(page: 0, currency: 'COP'),
      throwsA(
        isA<UnsupportedCurrencyError>().having(
          (e) => e.currency,
          'currency',
          'COP',
        ),
      ),
    );
  });

  test('a 400 in USD is a server error, not a currency problem', () async {
    final service = FourthwallService(
      client: MockClient((_) async => http.Response('{}', 400)),
    );
    expect(
      service.fetchProductsPage(page: 0, currency: 'USD'),
      throwsA(isA<ServerError>()),
    );
  });

  test('404 maps to NotFoundError; transport failures to network', () async {
    final notFound = FourthwallService(
      client: MockClient((_) async => http.Response('', 404)),
    );
    expect(
      notFound.fetchProduct('gone', currency: 'USD'),
      throwsA(isA<NotFoundError>()),
    );

    final offline = FourthwallService(
      client: MockClient((_) async => throw const SocketException('offline')),
    );
    expect(offline.fetchCollections(), throwsA(isA<NetworkConnectionError>()));
  });

  test('decodes collection names', () async {
    final service = FourthwallService(
      client: MockClient(
        (_) async => http.Response.bytes(
          '{"results":[{"id":"c1","slug":"womens","name":"Women&#39;s T-Shirts"}]}'
              .codeUnits,
          200,
        ),
      ),
    );
    final collections = await service.fetchCollections();
    expect(collections.single.name, "Women's T-Shirts");
  });

  test('checkout link carries every line, the currency and UTM tags', () {
    final uri = FourthwallService.checkoutUri([
      _item('v1', 2),
      _item('v2', 1),
    ], currency: 'GBP');
    expect(uri.host, FourthwallService.shopDomain);
    expect(uri.path, '/cart/checkout');
    expect(uri.queryParameters['products'], 'v1:2,v2:1');
    expect(uri.queryParameters['currency'], 'GBP');
    expect(uri.queryParameters['utm_source'], 'medito_app');
  });

  group('resolveCheckoutUri', () {
    final items = [_item('v1', 1)];

    FourthwallService redirectingTo(
      String? location, {
      int status = 303,
      void Function(http.BaseRequest)? onRequest,
    }) => FourthwallService(
      client: MockClient((request) async {
        onRequest?.call(request);
        return http.Response(
          '',
          status,
          headers: {if (location != null) 'location': location},
        );
      }),
    );

    test('opens the hosted checkout page with the UTM tags put back', () async {
      late http.BaseRequest sent;
      final uri = await redirectingTo(
        '/checkout/ch_abc',
        onRequest: (r) => sent = r,
      ).resolveCheckoutUri(items, currency: 'EUR');

      expect(sent.followRedirects, isFalse);
      expect(sent.url.path, '/cart/checkout');
      expect(sent.url.queryParameters['utm_source'], 'medito_app');
      expect(
        uri.toString(),
        'https://shop.medito.app/checkout/ch_abc'
        '?utm_source=medito_app&utm_medium=app',
      );
    });

    test(
      'falls back to the cart link when Fourthwall redirects to an error',
      () async {
        final uri = await redirectingTo(
          '/?error_message=Checkout%20unknown%20error',
        ).resolveCheckoutUri(items, currency: 'EUR');
        expect(uri, FourthwallService.checkoutUri(items, currency: 'EUR'));
      },
    );

    test('falls back to the cart link on a non-redirect response', () async {
      final uri = await redirectingTo(
        null,
        status: 500,
      ).resolveCheckoutUri(items, currency: 'EUR');
      expect(uri, FourthwallService.checkoutUri(items, currency: 'EUR'));
    });

    test('falls back to the cart link when the request fails', () async {
      final service = FourthwallService(
        client: MockClient((_) async => throw const SocketException('offline')),
      );
      final uri = await service.resolveCheckoutUri(items, currency: 'EUR');
      expect(uri, FourthwallService.checkoutUri(items, currency: 'EUR'));
    });
  });
}

BagItem _item(String id, int quantity) => BagItem(
  variantId: id,
  productSlug: 'p',
  productName: 'P',
  variantLabel: '',
  unitPrice: const ShopMoney(value: 10, currency: 'GBP'),
  quantity: quantity,
);
