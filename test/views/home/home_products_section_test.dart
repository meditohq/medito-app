import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/shop/shop_models.dart';
import 'package:medito/providers/shop/shop_providers.dart';
import 'package:medito/views/home/widgets/products/home_products_section.dart';

void main() {
  final products = [
    for (var i = 0; i < 12; i++)
      ShopProduct(id: '$i', slug: 's$i', name: 'P$i'),
  ];

  test('same day, same order; a different day reshuffles', () {
    final morning = dailyShuffle(products, DateTime(2026, 9, 26, 8));
    final evening = dailyShuffle(products, DateTime(2026, 9, 26, 22));
    final tomorrow = dailyShuffle(products, DateTime(2026, 9, 27, 8));

    expect(morning.map((p) => p.id), evening.map((p) => p.id));
    expect(tomorrow.map((p) => p.id), isNot(morning.map((p) => p.id)));
    expect(morning.map((p) => p.id).toSet(), products.map((p) => p.id).toSet());
  });

  test('curated lead stays first while the other products rotate daily', () {
    final home = HomeShopProducts(products: products, curated: true);
    final morning = homeProductsForDay(home, DateTime(2026, 9, 26, 8));
    final evening = homeProductsForDay(home, DateTime(2026, 9, 26, 22));
    final tomorrow = homeProductsForDay(home, DateTime(2026, 9, 27));

    expect(morning.first, products.first);
    expect(tomorrow.first, products.first);
    expect(evening, morning);
    expect(tomorrow[1], morning[2]);
    expect(tomorrow.last, morning[1]);
    expect(morning.toSet(), products.toSet());
    expect(home.products, products);
    expect(products.first.id, '0');

    final secondProducts = {
      for (var day = 0; day < products.length - 1; day++)
        homeProductsForDay(home, DateTime(2026, 9, 26 + day))[1].id,
    };
    expect(secondProducts, products.skip(1).map((p) => p.id).toSet());
  });

  test('empty and short curated collections keep all their products', () {
    for (var count = 0; count <= 2; count++) {
      final subset = products.take(count).toList();
      expect(
        homeProductsForDay(HomeShopProducts(products: subset, curated: true)),
        subset,
      );
    }
  });

  test('uncurated collections still shuffle the entire selection', () {
    final now = DateTime(2026, 9, 26);
    expect(
      homeProductsForDay(
        HomeShopProducts(products: products, curated: false),
        now,
      ),
      dailyShuffle(products, now),
    );
  });
}
