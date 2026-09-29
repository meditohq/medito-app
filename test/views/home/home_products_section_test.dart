import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/shop/shop_models.dart';
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
}
