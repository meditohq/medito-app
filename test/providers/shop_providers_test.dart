import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/shop/shop_models.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/shop/shop_providers.dart';
import 'package:medito/services/shop/fourthwall_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final page =
      jsonDecode(
            File(
              'test/fixtures/fourthwall_products_page.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final shirt = ShopProduct.fromJson(
    (page['results'] as List).first as Map<String, dynamic>,
  );
  final lilacS = shirt.variantFor(color: 'Lilac', size: 'S')!;
  final lilac2xl = shirt.variantFor(color: 'Lilac', size: '2XL')!;

  late SharedPreferences prefs;

  Future<ProviderContainer> makeContainer({
    Map<String, Object> seed = const {},
    List overrides = const [],
  }) async {
    SharedPreferences.setMockInitialValues(seed);
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides.cast(),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ShopBagNotifier', () {
    test('adding the same variant twice merges into one line', () async {
      final c = await makeContainer();
      final bag = c.read(shopBagProvider.notifier);
      bag.add(shirt, lilacS);
      bag.add(shirt, lilacS);
      bag.add(shirt, lilac2xl);

      final state = c.read(shopBagProvider);
      expect(state.items, hasLength(2));
      expect(state.items.first.quantity, 2);
      expect(state.quantity, 3);
      expect(state.subtotal?.value, 28 * 2 + 30);
      expect(state.items.first.variantLabel, 'Lilac, S');
      expect(state.items.first.imageUrl, lilacS.images.first.url);
    });

    test('quantity is capped and zero removes the line', () async {
      final c = await makeContainer();
      final bag = c.read(shopBagProvider.notifier);
      bag.add(shirt, lilacS, quantity: 50);
      expect(
        c.read(shopBagProvider).items.single.quantity,
        ShopBagNotifier.maxQuantity,
      );
      bag.setQuantity(lilacS.id, 0);
      expect(c.read(shopBagProvider).isEmpty, isTrue);
      expect(prefs.getString(SharedPreferenceConstants.shopBag), isNull);
    });

    test('persists and restores across containers', () async {
      final first = await makeContainer();
      first.read(shopBagProvider.notifier).add(shirt, lilacS);
      first.read(shopBagProvider.notifier).markCheckoutStarted();
      final saved = prefs.getString(SharedPreferenceConstants.shopBag)!;

      final second = await makeContainer(
        seed: {
          SharedPreferenceConstants.shopBag: saved,
          SharedPreferenceConstants.shopBagCheckoutStarted: true,
        },
      );
      final restored = second.read(shopBagProvider);
      expect(restored.items.single.variantId, lilacS.id);
      expect(restored.checkoutStarted, isTrue);
    });

    test(
      'changing the bag after checkout clears the "ordered?" prompt',
      () async {
        final c = await makeContainer();
        final bag = c.read(shopBagProvider.notifier);
        bag.add(shirt, lilacS);
        bag.markCheckoutStarted();
        expect(c.read(shopBagProvider).checkoutStarted, isTrue);
        bag.add(shirt, lilac2xl);
        expect(c.read(shopBagProvider).checkoutStarted, isFalse);
      },
    );

    test('an unreadable saved bag starts empty', () async {
      final c = await makeContainer(
        seed: {SharedPreferenceConstants.shopBag: 'not json'},
      );
      expect(c.read(shopBagProvider).isEmpty, isTrue);
    });
  });

  group('currency', () {
    test('device region picks the currency', () {
      expect(deviceCurrency(const Locale('en', 'GB')), 'GBP');
      expect(deviceCurrency(const Locale('es', 'MX')), 'MXN');
      expect(deviceCurrency(const Locale('en', 'US')), 'USD');
    });

    test(
      'falls back to USD once when Fourthwall rejects the currency',
      () async {
        final requested = <String>[];
        final service = FourthwallService(
          client: MockClient((request) async {
            final currency = request.url.queryParameters['currency']!;
            requested.add(currency);
            return currency == 'COP'
                ? http.Response('{}', 400)
                : http.Response.bytes(utf8.encode(jsonEncode(page)), 200);
          }),
        );
        final c = await makeContainer(
          overrides: [
            fourthwallServiceProvider.overrideWithValue(service),
            shopCurrencyProvider.overrideWith(() => _FixedCurrency('COP')),
          ],
        );

        final listing = await c.read(
          shopListingProvider(FourthwallService.allCollection).future,
        );

        expect(requested, ['COP', 'USD']);
        expect(c.read(shopCurrencyProvider), 'USD');
        expect(listing.products, hasLength(3));
      },
    );
  });

  test('loadMore appends the next page and stops at the end', () async {
    var calls = 0;
    final lastPage = {
      ...page,
      'paging': {'hasNextPage': false},
    };
    final service = FourthwallService(
      client: MockClient((request) async {
        calls++;
        final body = request.url.queryParameters['page'] == '0'
            ? page
            : lastPage;
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    );
    final c = await makeContainer(
      overrides: [
        fourthwallServiceProvider.overrideWithValue(service),
        shopCurrencyProvider.overrideWith(() => _FixedCurrency('USD')),
      ],
    );
    final provider = shopListingProvider(FourthwallService.allCollection);
    final sub = c.listen(provider, (_, _) {});
    addTearDown(sub.close);

    await c.read(provider.future);
    await c.read(provider.notifier).loadMore();
    final listing = c.read(provider).value!;
    expect(listing.products, hasLength(6));
    expect(listing.hasNextPage, isFalse);

    await c.read(provider.notifier).loadMore();
    expect(calls, 2);
  });

  group('home row and add-ons', () {
    Future<ProviderContainer> withShop(
      http.Response Function(String collection) respond,
    ) {
      final service = FourthwallService(
        client: MockClient((request) async {
          final segments = request.url.pathSegments;
          return respond(segments[segments.indexOf('collections') + 1]);
        }),
      );
      return makeContainer(
        overrides: [
          fourthwallServiceProvider.overrideWithValue(service),
          shopCurrencyProvider.overrideWith(() => _FixedCurrency('USD')),
        ],
      );
    }

    http.Response ok(List<Map<String, dynamic>> products) =>
        http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'results': products,
              'paging': {'hasNextPage': false},
            }),
          ),
          200,
        );

    final all = (page['results'] as List).cast<Map<String, dynamic>>();

    test('no curated collection falls back to the whole shop', () async {
      final c = await withShop(
        (collection) => collection == FourthwallService.homeCollection
            ? http.Response('', 404)
            : ok(all),
      );
      final home = await c.read(homeShopProductsProvider.future);
      expect(home.curated, isFalse);
      expect(home.products, hasLength(3));
    });

    test('a curated collection is used as-is', () async {
      final c = await withShop(
        (collection) => collection == FourthwallService.homeCollection
            ? ok([all[1]])
            : ok(all),
      );
      final home = await c.read(homeShopProductsProvider.future);
      expect(home.curated, isTrue);
      expect(home.products.single.slug, 'sleepy-cat-mug');
    });

    test('add-ons skip products already in the bag', () async {
      final c = await withShop((_) => ok(all));
      c.read(shopBagProvider.notifier).add(shirt, lilacS);
      final addOns = await c.read(shopAddOnsProvider.future);
      expect(addOns.map((p) => p.slug), isNot(contains(shirt.slug)));
      expect(addOns, hasLength(2));
    });
  });
}

class _FixedCurrency extends ShopCurrencyNotifier {
  _FixedCurrency(this.currency);

  final String currency;

  @override
  String build() => currency;
}
